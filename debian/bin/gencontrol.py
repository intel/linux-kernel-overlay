#!/usr/bin/python3

from __future__ import annotations

import dataclasses
import json
import locale
import os
import os.path
import pathlib
import subprocess
import re
from typing import cast

from debian_linux.config_v2 import (
    Config,
    ConfigMerged,
    ConfigMergedDebianarch,
    ConfigMergedFeatureset,
    ConfigMergedFlavour,
)
from debian_linux.dataclasses_deb822 import read_deb822, write_deb822
from debian_linux.debian import \
    PackageBuildprofile, \
    PackageRelation, PackageRelationEntry, PackageRelationGroup, \
    VersionLinux, BinaryPackage
from debian_linux.gencontrol import Gencontrol as Base, PackagesBundle, \
    MakeFlags
from debian_linux.utils import Templates

locale.setlocale(locale.LC_CTYPE, "C.UTF-8")


class Gencontrol(Base):
    disable_installer: bool
    disable_signed: bool
    disable_tools: bool

    env_flags = [
        ('DEBIAN_KERNEL_DISABLE_INSTALLER', 'disable_installer', 'installer modules'),
        ('DEBIAN_KERNEL_DISABLE_SIGNED', 'disable_signed', 'signed code'),
    ]

    def __init__(
        self,
        config_dirs=[
            pathlib.Path('debian/config'),
            pathlib.Path('debian/config.local'),
        ],
        template_dirs=["debian/templates"],
    ) -> None:
        super().__init__(
            Config.read_orig(config_dirs).merged,
            Templates(template_dirs),
            VersionLinux)
        self.config_dirs = config_dirs

        for debianrelease in self.config.debianreleases:
            if debianrelease.name_regex.fullmatch(self.changelog[0].distribution):
                self.debianrelease = debianrelease
                break
        else:
            raise RuntimeError(
                f'No debianrelease config matches {self.changelog[0].distribution}')

        self.process_changelog()

        for env, attr, desc in self.env_flags:
            setattr(self, attr, False)
            if os.getenv(env):
                if self.changelog[0].distribution == 'UNRELEASED':
                    import warnings
                    warnings.warn(f'Disable {desc} on request ({env} set)')
                    setattr(self, attr, True)
                else:
                    raise RuntimeError(
                        f'Unable to disable {desc} in release build ({env} set)')

        # Check DEB_BUILD_PROFILES for pkg.linux.notools
        self.disable_tools = False
        build_profiles = os.getenv('DEB_BUILD_PROFILES', '').split()
        if 'pkg.linux.notools' in build_profiles:
            import warnings
            warnings.warn('Disable kernel tools on request (pkg.linux.notools profile)')
            self.disable_tools = True

    def _setup_makeflags(self, names, makeflags, data) -> None:
        for src, dst, optional in names:
            if src in data or not optional:
                makeflags[dst] = data[src]

    def do_main_setup(
        self,
        config: ConfigMerged,
        vars: dict[str, str],
        makeflags: MakeFlags,
    ) -> None:
        super().do_main_setup(config, vars, makeflags)
        makeflags.update({
            'UPSTREAMVERSION': self.version.linux_version,
            'ABINAME': self.abiname,
            'SOURCEVERSION': self.version.complete,
        })
        makeflags['SOURCE_BASENAME'] = vars['source_basename']
        makeflags['SOURCE_SUFFIX'] = vars['source_suffix']

        # Prepare to generate debian/tests/control
        self.tests_control = list(self.templates.get_tests_control('main.tests-control', vars))

    def do_main_makefile(
        self,
        config: ConfigMerged,
        vars: dict[str, str],
        makeflags: MakeFlags,
    ) -> None:
        for featureset in self.config.root_featuresets:
            makeflags_featureset = makeflags.copy()
            makeflags_featureset['FEATURESET'] = featureset.name

            self.bundle.makefile.add_rules(f'source_{featureset.name}',
                                           'source', makeflags_featureset)
            self.bundle.makefile.add_deps('source', [f'source_{featureset.name}'])

        makeflags = makeflags.copy()
        makeflags['ALL_FEATURESETS'] = ' '.join(i.name for i in self.config.root_featuresets)
        super().do_main_makefile(config, vars, makeflags)

    def do_main_packages(
        self,
        config: ConfigMerged,
        vars: dict[str, str],
        makeflags: MakeFlags,
    ) -> None:
        self.bundle.add('main', (), makeflags, vars)

        # Only build the metapackages if their names won't exactly match
        # the packages they depend on
        do_meta = config.packages.meta \
            and vars['source_suffix'] != '-' + vars['version']

        if config.packages.docs:
            self.bundle.add('docs', (), makeflags, vars)
            if do_meta:
                self.bundle.add('docs.meta', (), makeflags, vars)
        if config.packages.source:
            self.bundle.add('sourcebin', (), makeflags, vars)
            if do_meta:
                self.bundle.add('sourcebin.meta', (), makeflags, vars)

        if config.packages.libc_dev:
            libcdev_kernel = set()
            libcdev_spec = set()
            libcdev_spec_cross = set()
            for kernelarch in self.config.kernelarchs:
                libcdev_kernel.add(kernelarch.name)
                for debianarch in kernelarch.debianarchs:
                    libcdev_spec_cross.add(
                        f'{debianarch.defs_debianarch.multiarch}:{kernelarch.name}'
                    )
                    if not debianarch.packages.libc_dev_cross_only:
                        libcdev_spec.add(
                            f'{debianarch.defs_debianarch.multiarch}:{kernelarch.name}'
                        )

            libcdev_makeflags = makeflags.copy()
            libcdev_makeflags['ALL_LIBCDEV_KERNEL'] = ' '.join(sorted(libcdev_kernel))
            libcdev_makeflags['ALL_LIBCDEV_SPEC'] = ' '.join(sorted(libcdev_spec))
            libcdev_makeflags['ALL_LIBCDEV_SPEC_CROSS'] = ' '.join(sorted(libcdev_spec_cross))

            self.bundle.add('libc-dev', (), libcdev_makeflags, vars)

            # Cross-compilation support disabled
            # for kernelarch in self.config.kernelarchs:
            #     for debianarch in kernelarch.debianarchs:
            #         self.bundle.add('libc-dev-cross', (), libcdev_makeflags, vars | {
            #             'libcdev_debian': debianarch.name,
            #             'libcdev_multiarch': debianarch.defs_debianarch.multiarch,
            #         })

    def do_indep_featureset_setup(
        self,
        config: ConfigMergedFeatureset,
        vars: dict[str, str],
        makeflags: MakeFlags,
    ) -> None:
        makeflags['LOCALVERSION'] = vars['localversion']
        kernel_arches = set()
        for kernelarch in self.config.kernelarchs:
            for debianarch in kernelarch.debianarchs:
                for featureset in debianarch.featuresets:
                    if config.name_featureset in featureset.name:
                        kernel_arches.add(kernelarch.name)
        makeflags['ALL_KERNEL_ARCHES'] = ' '.join(sorted(list(kernel_arches)))

        vars['featureset_desc'] = ''
        if config.name_featureset != 'none':
            desc = config.description
            vars['featureset_desc'] = (' with the %s featureset' %
                                       desc.short[desc.parts[0]])

    def do_indep_featureset_packages(
        self,
        config: ConfigMergedFeatureset,
        vars: dict[str, str],
        makeflags: MakeFlags,
    ) -> None:
        self.bundle.add('headers.featureset', (config.name_featureset, ), makeflags, vars)

    def do_arch_setup(
        self,
        config: ConfigMergedDebianarch,
        vars: dict[str, str],
        makeflags: MakeFlags,
    ) -> None:
        makeflags['KERNEL_ARCH'] = vars['kernel_arch'] = config.name_kernelarch

    def do_arch_packages(
        self,
        config: ConfigMergedDebianarch,
        vars: dict[str, str],
        makeflags: MakeFlags,
    ) -> None:
        arch = config.name

        if not self.disable_signed:
            build_signed = config.build.enable_signed
        else:
            build_signed = False

        if build_signed:
            # Make sure variables remain
            vars['signedtemplate_binaryversion'] = '@signedtemplate_binaryversion@'
            vars['signedtemplate_sourceversion'] = '@signedtemplate_sourceversion@'

            self.bundle.add('signed-template', (arch,), makeflags, vars, arch=arch)

            bundle_signed = self.bundles[f'signed-{arch}'] = \
                PackagesBundle(f'signed-{arch}', 'signed.source.control', vars, self.templates)

            with bundle_signed.open('source/lintian-overrides', 'w') as f:
                f.write(self.substitute(
                    self.templates.get('signed.source.lintian-overrides'), vars))

            with bundle_signed.open('changelog.head', 'w') as f:
                dist = self.changelog[0].distribution
                urgency = self.changelog[0].urgency
                f.write(f'''\
linux-signed-{vars['arch']} (@signedtemplate_sourceversion@) {dist}; urgency={urgency}

  * Sign kernel from {self.changelog[0].source} @signedtemplate_binaryversion@
''')

        if config.packages.source and list(config.featuresets):
            self.bundle.add('config', (arch, ), makeflags, vars)

        if config.packages.tools_unversioned and not self.disable_tools:
            self.bundle.add('tools-unversioned', (arch, ), makeflags, vars)

        if config.packages.tools_versioned and not self.disable_tools:
            self.bundle.add('tools-versioned', (arch, ), makeflags, vars)

    def do_featureset_setup(
        self,
        featureset: ConfigMergedFeatureset,
        vars: dict[str, str],
        makeflags: MakeFlags,
    ) -> None:
        vars['localversion_headers'] = vars['localversion']
        makeflags['LOCALVERSION_HEADERS'] = vars['localversion_headers']

    def do_flavour_setup(
        self,
        config: ConfigMergedFlavour,
        vars: dict[str, str],
        makeflags: MakeFlags,
    ) -> None:
        vars['flavour'] = vars['localversion'][1:]
        vars['class'] = config.description.hardware or ''
        vars['longclass'] = config.description.hardware_long or vars['class']

        vars['localversion-image'] = vars['localversion']

        vars['image-stem'] = cast(str, config.build.kernel_stem)

        if t := config.build.cflags:
            makeflags['KCFLAGS'] = t
        makeflags['C_COMPILER'] = config.build.c_compiler
        if t := config.build.compiler_gnutype:
            makeflags['KERNEL_GNU_TYPE'] = t
        if t := config.build.compiler_gnutype_compat:
            makeflags['COMPAT_GNU_TYPE'] = t
        makeflags['IMAGE_FILE'] = config.build.kernel_file
        makeflags['IMAGE_INSTALL_STEM'] = config.build.kernel_stem

        makeflags['LOCALVERSION'] = vars['localversion']
        makeflags['LOCALVERSION_IMAGE'] = vars['localversion-image']

    def do_flavour_packages(
        self,
        config: ConfigMergedFlavour,
        vars: dict[str, str],
        makeflags: MakeFlags,
    ) -> None:
        arch = config.name_debianarch
        ruleid = (arch, config.name_featureset, config.name_flavour)

        packages_headers = (
            self.bundle.add('headers', ruleid, makeflags, vars, arch=arch)
        )
        assert len(packages_headers) == 1

        do_meta = config.packages.meta

        relation_c_compiler = PackageRelationEntry(cast(str, config.build.c_compiler))
        relation_c_compiler_host = PackageRelationEntry(
            relation_c_compiler,
            name=f'{relation_c_compiler.name}-for-host',
        )

        # Generate compiler build-depends:
        self.bundle.source.build_depends_arch.merge([
            PackageRelationEntry(
                relation_c_compiler_host,
                arches={arch},
                restrictions='<!pkg.linux.nokernel>',
            )
        ])
        if config.build.enable_rust:
            for group in config.build.rust_build_depends:
                self.bundle.source.build_depends_arch.merge(
                    PackageRelationGroup(
                        group,
                        arches={arch},
                        restrictions='<!pkg.linux.nokernel !pkg.linux.norust>',
                    )
                )

        # Generate compiler build-depends for kernel:
        # gcc-N-hppa64-linux-gnu [hppa] <!pkg.linux.nokernel>
        if gnutype := config.build.compiler_gnutype:
            if gnutype != config.defs_debianarch.gnutype:
                self.bundle.source.build_depends_arch.merge([
                    PackageRelationEntry(
                        relation_c_compiler,
                        name=f'{relation_c_compiler.name}-{gnutype.replace("_", "-")}',
                        arches={arch},
                        restrictions='<!pkg.linux.nokernel>',
                    )
                ])

        # Generate compiler build-depends for compat:
        # gcc-arm-linux-gnueabihf [arm64] <!pkg.linux.nokernel>
        # XXX: Linux uses various definitions for this, all ending with "gcc", not $CC
        if gnutype := config.build.compiler_gnutype_compat:
            if gnutype != config.defs_debianarch.gnutype:
                self.bundle.source.build_depends_arch.merge([
                    PackageRelationEntry(
                        f'gcc-{gnutype.replace("_", "-")}',
                        arches={arch},
                        restrictions='<!pkg.linux.nokernel>',
                    )
                ])

        if config.build.enable_dtb:
            makeflags['ENABLE_DTB'] = True

        packages_own = []

        build_installer = (
            config.name_featureset == 'none'
            and not self.disable_installer
            and config.packages.installer
        )

        if not self.disable_signed:
            build_signed = config.build.enable_signed
        else:
            build_signed = False

        if build_signed:
            bundle_signed = self.bundles[f'signed-{arch}']
        else:
            bundle_signed = self.bundle

        vars.setdefault('desc', '')

        packages_own.extend(self.bundle.add('base', ruleid, makeflags, vars, arch=arch))
        packages_own.extend(self.bundle.add('modules', ruleid, makeflags, vars, arch=arch))

        if build_signed:
            packages_binary_unsigned = (
                self.bundle.add('binary-unsigned', ruleid, makeflags, vars, arch=arch)
            )
            packages_binary = packages_binary_unsigned[:]
            packages_binary.extend(
                bundle_signed.add('signed.binary', ruleid, makeflags, vars, arch=arch)
            )

        else:
            packages_binary = packages_binary_unsigned = (
                bundle_signed.add('binary', ruleid, makeflags, vars, arch=arch)
            )

        packages_image = (
            bundle_signed.add('image', ruleid, makeflags, vars, arch=arch)
        )

        for field in ('Depends', 'Provides', 'Suggests', 'Recommends',
                      'Conflicts', 'Breaks'):
            for i in getattr(config.relations.image, field.lower(), []):
                for package_image in packages_image:
                    getattr(package_image, field.lower()).merge(
                        PackageRelationGroup(i, arches={arch})
                    )

        for field in ('Depends', 'Suggests', 'Recommends'):
            for i in getattr(config.relations.image, field.lower(), []):
                group = PackageRelationGroup(i, arches={arch})
                for entry in group:
                    if entry.operator is not None:
                        entry.operator = -entry.operator
                        for package_image in packages_image:
                            package_image.breaks.append(PackageRelationGroup([entry]))

        if desc_parts := config.description.parts:
            # XXX: Workaround, we need to support multiple entries of the same
            # name
            parts = list(set(desc_parts))
            parts.sort()
            for package_image in packages_image:
                desc = package_image.description
                for part in parts:
                    desc.append(config.description.long[part])
                    desc.append_short(config.description.short[part])

        packages_headers[0].depends.merge([relation_c_compiler_host])
        packages_own.extend(packages_binary)
        packages_own.extend(packages_image)
        packages_own.extend(packages_headers)

        if do_meta:
            packages_own.extend(bundle_signed.add('base.meta', ruleid, makeflags, vars, arch=arch))

            packages_meta = (
                bundle_signed.add('image.meta', ruleid, makeflags, vars, arch=arch)
            )
            assert len(packages_meta) == 1
            packages_meta += (
                bundle_signed.add('headers.meta', ruleid, makeflags, vars, arch=arch)
            )
            assert len(packages_meta) == 2

            if (
                config.defs_flavour.is_default
                and not self.vars['source_suffix']
            ):
                packages_meta[0].provides.append('linux-image-generic')
                packages_meta[1].provides.append('linux-headers-generic')

            packages_own.extend(packages_meta)

        packages_own.extend(
            self.bundle.add('image-dbg', ruleid, makeflags, vars, arch=arch)
        )
        if do_meta:
            packages_own.extend(
                bundle_signed.add('image-dbg.meta', ruleid, makeflags, vars, arch=arch)
            )

        if (
            config.defs_flavour.is_default
            # XXX
            and not self.vars['source_suffix']
        ):
            packages_own.extend(
                self.bundle.add('image-extra-dev', ruleid, makeflags, vars, arch=arch)
            )

        if build_installer:
            packages_base_di = self.bundle.add('base-di', ruleid, makeflags, vars, arch=arch) \
                    + bundle_signed.add('binary-di', ruleid, makeflags, vars, arch=arch)
            packages_own.extend(packages_base_di)
            depends_base_di = PackageRelation(i.name for i in packages_base_di)

        # In a quick build, only build the test flavour.
        if config.defs_flavour.is_test:
            for package in packages_own:
                package.build_profiles[0].pos.add('pkg.linux.quick')
        else:
            for package in packages_own:
                package.build_profiles[0].neg.add('pkg.linux.quick')

        tests_control_image = list(
            self.templates.get_tests_control('binary.tests-control', vars))
        for c in tests_control_image:
            c.depends.extend(
                [i.name for i in packages_binary_unsigned]
            )

        tests_control_headers = list(
            self.templates.get_tests_control('headers.tests-control', vars))
        for c in tests_control_headers:
            c.depends.extend(
                [i.name for i in packages_headers] +
                [i.name for i in packages_binary_unsigned]
            )

        self.tests_control.extend(tests_control_image)
        self.tests_control.extend(tests_control_headers)

        kconfig = []
        for c in (config.config_nodefault if config.defs_flavour.is_test else config.config):
            for d in self.config_dirs:
                if (f := d / c).exists():
                    kconfig.append(str(f))
        makeflags['KCONFIG'] = ' '.join(kconfig)
        makeflags['KCONFIG_OPTIONS'] = ''
        # Add "salt" to fix #872263
        makeflags['KCONFIG_OPTIONS'] += \
            ' -o "BUILD_SALT=\\"%(abiname)s%(localversion)s\\""' % vars

        merged_config = ('debian/build/config.%s_%s_%s' %
                         (config.name_debianarch, config.name_featureset, config.name_flavour))
        self.bundle.makefile.add_cmds(merged_config,
                                      ["$(MAKE) -f debian/rules.real %s %s" %
                                       (merged_config, makeflags)])

        # The test flavour is known to not work at all with kernel-wedge.  Also
        # we misshandle pkg.linux.quick for it.
        if (
            build_installer
            and not config.defs_flavour.is_test
        ):
            # Add udebs using kernel-wedge
            kw_env = os.environ.copy()
            kw_env['KW_CONFIG_DIR'] = 'debian/installer'
            kw_proc = subprocess.Popen(
                [
                    'debian/installer/kernel-wedge/gen-control',
                    arch, vars['abiname'], vars['flavour'],
                ],
                stdout=subprocess.PIPE,
                text=True,
                env=kw_env)
            assert kw_proc.stdout is not None
            udeb_packages_base = list(read_deb822(BinaryPackage, kw_proc.stdout))
            kw_proc.wait()
            if kw_proc.returncode != 0:
                raise RuntimeError('kernel-wedge exited with code %d' %
                                   kw_proc.returncode)

            udeb_packages = [
                dataclasses.replace(
                    package_base,
                    # kernel-wedge does not support versioned extra packages,
                    # so inject the base dependency here.
                    depends=PackageRelation(depends_base_di + package_base.depends),
                    # kernel-wedge currently chokes on Build-Profiles so add it now
                    build_profiles=PackageBuildprofile.parse(
                        '<!noudeb !pkg.linux.nokernel !pkg.linux.quick>',
                    ),
                    meta_rules_target='installer',
                )
                for package_base in udeb_packages_base
            ]

            self.bundle.add_packages(
                udeb_packages,
                (config.name_debianarch, config.name_featureset, config.name_flavour),
                makeflags, arch=arch,
            )

    def process_changelog(self) -> None:
        version = self.version = self.changelog[0].version

        if self.debianrelease.abi_version_full:
            self.abiname = version.linux_version_full + self.debianrelease.abi_suffix
            # Disabled ABI serial number suffix for custom Intel kernel builds.
            # The abi_suffix already carries a unique timestamp (-intel+TIMESTAMP),
            # so abiname is naturally unique without the .{n-1} serial. Adding the
            # serial caused the kernel image version (no .N) and module directory
            # name (with .N) to mismatch when the changelog had multiple entries
            # of the same upstream version + distribution.
            #
            # Original logic:
            # n = sum(1
            #         for entry in self.changelog
            #         if (entry.version.linux_version_full == version.linux_version_full
            #             and self.debianrelease.name_regex.fullmatch(entry.distribution)))
            # if n > 1:
            #     self.abiname += f'.{n-1}'
        else:
            self.abiname = version.linux_version + self.debianrelease.abi_suffix

        self.vars = {
            'upstreamversion': self.version.linux_version_full,
            'version': self.version.linux_version,
            'version_complete': self.version.complete,
            'source_basename': re.sub(r'-[\d.]+$', '',
                                      self.changelog[0].source),
            'source_upstream': self.version.upstream,
            'source_package': self.changelog[0].source,
            'abiname': self.abiname,
        }
        self.vars['source_suffix'] = \
            self.changelog[0].source[len(self.vars['source_basename']):]

        if not self.debianrelease.revision_regex.fullmatch(version.revision):
            raise RuntimeError(
                f"Can't upload to {self.changelog[0].distribution} with a version of {version}")

    def write(self) -> None:
        super().write()
        self.write_tests_control()
        self.write_signed()

    def write_signed(self) -> None:
        for bundle in self.bundles.values():
            pkg_sign_entries_notquick = {}
            pkg_sign_entries_quick = {}

            for p in bundle.packages.values():
                if not isinstance(p, BinaryPackage):
                    continue

                if pkg_sign_pkg := p.meta_sign_package:
                    e = {
                        'trusted_certs': [],
                        'files': [
                            {
                                'sig_type': e.split(':', 1)[-1],
                                'file': e.split(':', 1)[0],
                            }
                            for e in p.meta_sign_files
                        ],
                    }

                    if 'pkg.linux.quick' in p.build_profiles[0].pos:
                        pkg_sign_entries_quick[pkg_sign_pkg] = e
                    else:
                        pkg_sign_entries_notquick[pkg_sign_pkg] = e

            if pkg_sign_entries_notquick or pkg_sign_entries_quick:
                with bundle.path('files.notquick.json').open('w') as f:
                    json.dump({'packages': pkg_sign_entries_notquick}, f, indent=2)
                with bundle.path('files.quick.json').open('w') as f:
                    json.dump({'packages': pkg_sign_entries_quick}, f, indent=2)

    def write_tests_control(self) -> None:
        # Skip writing tests/control as autopkgtest has been removed
        pass


if __name__ == '__main__':
    Gencontrol()()
