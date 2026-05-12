import pytest

from .debian import (
    Version,
    VersionLinux,
    PackageArchitecture,
    PackageDescription,
    PackageRelationEntry,
    PackageRelationGroup,
    PackageRelation,
    PackageBuildprofileEntry,
    PackageBuildprofile,
)


class TestVersion:
    def test_native(self) -> None:
        v = Version('1.2+c~4')
        assert v.epoch is None
        assert v.upstream == '1.2+c~4'
        assert v.revision is None
        assert v.complete == '1.2+c~4'
        assert v.complete_noepoch == '1.2+c~4'

    def test_nonnative(self) -> None:
        v = Version('1-2+d~3')
        assert v.epoch is None
        assert v.upstream == '1'
        assert v.revision == '2+d~3'
        assert v.complete == '1-2+d~3'
        assert v.complete_noepoch == '1-2+d~3'

    def test_native_epoch(self) -> None:
        v = Version('5:1.2.3')
        assert v.epoch == 5
        assert v.upstream == '1.2.3'
        assert v.revision is None
        assert v.complete == '5:1.2.3'
        assert v.complete_noepoch == '1.2.3'

    def test_nonnative_epoch(self) -> None:
        v = Version('5:1.2.3-4')
        assert v.epoch == 5
        assert v.upstream == '1.2.3'
        assert v.revision == '4'
        assert v.complete == '5:1.2.3-4'
        assert v.complete_noepoch == '1.2.3-4'

    def test_multi_hyphen(self) -> None:
        v = Version('1-2-3')
        assert v.epoch is None
        assert v.upstream == '1-2'
        assert v.revision == '3'
        assert v.complete == '1-2-3'

    def test_multi_colon(self) -> None:
        v = Version('1:2:3')
        assert v.epoch == 1
        assert v.upstream == '2:3'
        assert v.revision is None

    def test_invalid_epoch(self) -> None:
        with pytest.raises(RuntimeError):
            Version('a:1')
        with pytest.raises(RuntimeError):
            Version('-1:1')
        with pytest.raises(RuntimeError):
            Version('1a:1')

    def test_invalid_upstream(self) -> None:
        with pytest.raises(RuntimeError):
            Version('1_2')
        with pytest.raises(RuntimeError):
            Version('1/2')
        with pytest.raises(RuntimeError):
            Version('a1')
        with pytest.raises(RuntimeError):
            Version('1 2')

    def test_invalid_revision(self) -> None:
        with pytest.raises(RuntimeError):
            Version('1-2_3')
        with pytest.raises(RuntimeError):
            Version('1-2/3')
        with pytest.raises(RuntimeError):
            Version('1-2:3')


class TestVersionLinux:
    def test_stable(self) -> None:
        v = VersionLinux('1.2.3-4')
        assert v.linux_version == '1.2'
        assert v.linux_version_full == '1.2.3'

    def test_rc(self) -> None:
        v = VersionLinux('1.2~rc3-4')
        assert v.linux_version == '1.2'
        assert v.linux_version_full == '1.2-rc3'

    def test_update(self) -> None:
        v = VersionLinux('1.2.3-a1~rc3-4')
        assert v.linux_version == '1.2'
        assert v.linux_version_full == '1.2.3-a1-rc3'


class TestPackageArchitecture:
    def test_init(self) -> None:
        a = PackageArchitecture()
        assert a == set()

    def test_init_str(self) -> None:
        a = PackageArchitecture(' foo  bar\tbaz ')
        assert a == {'foo', 'bar', 'baz'}

    def test_init_iter(self) -> None:
        a = PackageArchitecture(('foo', 'bar'))
        assert a == {'foo', 'bar'}

    def test_init_self(self) -> None:
        a = PackageArchitecture(PackageArchitecture(('foo', 'bar')))
        assert a == {'foo', 'bar'}

    def test_str(self) -> None:
        a = PackageArchitecture(('foo', 'bar'))
        assert str(a) == 'bar foo'


class TestPackageDescription:
    def test_init(self) -> None:
        a = PackageDescription()
        assert a.short == []
        assert a.long == []

    def test_init_str(self) -> None:
        a = PackageDescription('Short\nLong1\n.\nLong2')
        assert a.short == ['Short']
        assert a.long == ['Long1', 'Long2']

    def test_init_self(self) -> None:
        a = PackageDescription(PackageDescription('Short\nLong1\n.\nLong2'))
        assert a.short == ['Short']
        assert a.long == ['Long1', 'Long2']

    def test_str(self) -> None:
        a = PackageDescription('Short\nLong1\n.\nLong2')
        assert str(a) == 'Short\nLong1\n.\nLong2'


class TestPackageRelationEntry:
    def test_init_str(self) -> None:
        a = PackageRelationEntry('package (>=version) [arch2 arch1] <profile1 >')
        assert a.name == 'package'
        assert a.version == 'version'
        assert a.arches == {'arch1', 'arch2'}
        # TODO: assert a.profiles
        assert str(a) == 'package (>= version) [arch1 arch2] <profile1>'

    def test_init_self(self) -> None:
        a = PackageRelationEntry(PackageRelationEntry('package [arch2 arch1]'))
        assert a.name == 'package'
        assert a.arches == {'arch1', 'arch2'}
        assert str(a) == 'package [arch1 arch2]'


class TestPackageRelationGroup:
    def test_init(self) -> None:
        a = PackageRelationGroup()
        assert a == []

    def test_init_str(self) -> None:
        a = PackageRelationGroup('foo | bar')
        assert len(a) == 2
        assert a[0].name == 'foo'
        assert a[1].name == 'bar'

    def test_init_iter_entry(self) -> None:
        a = PackageRelationGroup((PackageRelationEntry('foo'), PackageRelationEntry('bar')))
        assert len(a) == 2
        assert a[0].name == 'foo'
        assert a[1].name == 'bar'

    def test_init_iter_str(self) -> None:
        a = PackageRelationGroup(('foo', 'bar'))
        assert len(a) == 2
        assert a[0].name == 'foo'
        assert a[1].name == 'bar'

    def test_init_self(self) -> None:
        a = PackageRelationGroup(PackageRelationGroup(['foo', 'bar']))
        assert len(a) == 2
        assert a[0].name == 'foo'
        assert a[1].name == 'bar'

    def test_str(self) -> None:
        a = PackageRelationGroup('foo|  bar')
        assert str(a) == 'foo | bar'


class TestPackageRelation:
    def test_init(self) -> None:
        a = PackageRelation()
        assert a == []

    def test_init_str(self) -> None:
        a = PackageRelation('foo1 | foo2, bar')
        assert len(a) == 2
        assert len(a[0]) == 2
        assert a[0][0].name == 'foo1'
        assert a[0][1].name == 'foo2'
        assert len(a[1]) == 1
        assert a[1][0].name == 'bar'

    def test_init_iter_entry(self) -> None:
        a = PackageRelation([[PackageRelationEntry('foo')], [PackageRelationEntry('bar')]])
        assert len(a) == 2
        assert len(a[0]) == 1
        assert a[0][0].name == 'foo'
        assert len(a[1]) == 1
        assert a[1][0].name == 'bar'

    def test_init_iter_str(self) -> None:
        a = PackageRelation(('foo', 'bar'))
        assert len(a) == 2
        assert len(a[0]) == 1
        assert a[0][0].name == 'foo'
        assert len(a[1]) == 1
        assert a[1][0].name == 'bar'

    def test_init_self(self) -> None:
        a = PackageRelation(PackageRelation(('foo', 'bar')))
        assert len(a) == 2
        assert len(a[0]) == 1
        assert a[0][0].name == 'foo'
        assert len(a[1]) == 1
        assert a[1][0].name == 'bar'

    def test_str(self) -> None:
        a = PackageRelation('${misc:Depends} , foo ,bar')
        assert str(a) == 'bar, foo, ${misc:Depends}'


class TestPackageBuildprofileEntry:
    def test_parse(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 !profile2 profile3 !profile4')
        assert a.pos == {'profile1', 'profile3'}
        assert a.neg == {'profile2', 'profile4'}
        assert str(a) == 'profile1 profile3 !profile2 !profile4'

    def test_parse_empty(self) -> None:
        a = PackageBuildprofileEntry.parse('')
        assert a.pos == set()
        assert a.neg == set()
        assert str(a) == ''

    def test_parse_impossible(self) -> None:
        with pytest.raises(ValueError):
            PackageBuildprofileEntry.parse('profile !profile')

    def test_eq(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 !profile2')
        b = PackageBuildprofileEntry(pos={'profile1'}, neg={'profile2'})
        assert a == b

    def test_len(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 !profile2')
        assert len(a) == 2

    def test_len_empty(self) -> None:
        a = PackageBuildprofileEntry()
        assert len(a) == 0

    def test_isdisjoint_empty(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1')
        b = PackageBuildprofileEntry()
        assert not a.isdisjoint(b)

    def test_isdisjoint_pos(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 profile2')
        b = PackageBuildprofileEntry.parse('profile1 profile3')
        assert a.isdisjoint(b)

    def test_isdisjoint_neg(self) -> None:
        a = PackageBuildprofileEntry.parse('!profile1 !profile2')
        b = PackageBuildprofileEntry.parse('!profile1 !profile3')
        assert a.isdisjoint(b)

    def test_issubset_empty(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 profile2')
        b = PackageBuildprofileEntry()
        assert a.issubset(b)

    def test_issubset_pos(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 profile2')
        b = PackageBuildprofileEntry.parse('profile1')
        assert a.issubset(b)

    def test_issubset_neg(self) -> None:
        a = PackageBuildprofileEntry.parse('!profile1')
        b = PackageBuildprofileEntry.parse('!profile1 !profile2')
        assert a.issubset(b)

    def test_issubset_both(self) -> None:
        a = PackageBuildprofileEntry.parse('!profile1 !profile2 profile3')
        b = PackageBuildprofileEntry.parse('!profile1 !profile2 !profile3')
        assert a.issubset(b)

    def test_issuperset_empty(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 profile2')
        b = PackageBuildprofileEntry()
        assert b.issuperset(a)

    def test_issuperset_pos(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 profile2')
        b = PackageBuildprofileEntry.parse('profile1')
        assert b.issuperset(a)

    def test_issuperset_neg(self) -> None:
        a = PackageBuildprofileEntry.parse('!profile1')
        b = PackageBuildprofileEntry.parse('!profile1 !profile2')
        assert b.issuperset(a)

    def test_issuperset_both(self) -> None:
        a = PackageBuildprofileEntry.parse('!profile1 !profile2 profile3')
        b = PackageBuildprofileEntry.parse('!profile1 !profile2 !profile3')
        assert b.issuperset(a)

    def test_update_pos(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 profile2')
        b = PackageBuildprofileEntry.parse('profile1')
        a.update(b)
        assert a.pos == {'profile1'}
        assert a.neg == set()

    def test_update_neg(self) -> None:
        a = PackageBuildprofileEntry.parse('!profile1 !profile2')
        b = PackageBuildprofileEntry.parse('!profile1')
        a.update(b)
        assert a.pos == set()
        assert a.neg == {'profile1'}

    def test_update_both(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 !profile2 profile3')
        b = PackageBuildprofileEntry.parse('profile1 !profile2 !profile3')
        a.update(b)
        assert a.pos == {'profile1'}
        assert a.neg == {'profile2'}

    def test_intersection_update_pos(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 profile2')
        b = PackageBuildprofileEntry.parse('profile1')
        a.intersection_update(b)
        assert a.pos == {'profile1', 'profile2'}
        assert a.neg == set()

    def test_intersection_update_neg(self) -> None:
        a = PackageBuildprofileEntry.parse('!profile1 !profile2')
        b = PackageBuildprofileEntry.parse('!profile1')
        a.intersection_update(b)
        assert a.pos == set()
        assert a.neg == {'profile1', 'profile2'}

    def test_intersection_update_both(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1 !profile2')
        b = PackageBuildprofileEntry.parse('profile1 !profile3')
        a.intersection_update(b)
        assert a.pos == {'profile1'}
        assert a.neg == {'profile2', 'profile3'}

    def test_intersection_update_negate(self) -> None:
        a = PackageBuildprofileEntry.parse('profile1')
        b = PackageBuildprofileEntry.parse('!profile1')
        a.intersection_update(b)
        assert a.pos == set()
        assert a.neg == set()


class TestPackageBuildprofile:
    def test_parse(self) -> None:
        a = PackageBuildprofile.parse('<profile1> <!profile2> <profile3> <!profile4>')
        assert str(a) == '<profile1> <!profile2> <profile3> <!profile4>'

    def test_update(self) -> None:
        a = PackageBuildprofile.parse('<profile1> <profile2 profile3>')
        b = PackageBuildprofile.parse('<profile3>')
        a.update(b)
        assert str(a) == '<profile1> <profile3>'

    def test_update_empty(self) -> None:
        a = PackageBuildprofile.parse('')
        b = PackageBuildprofile.parse('<profile1>')
        a.update(b)
        assert str(a) == ''

        a = PackageBuildprofile.parse('<profile1>')
        b = PackageBuildprofile.parse('')
        a.update(b)
        assert str(a) == ''

    def test_intersection_update(self) -> None:
        a = PackageBuildprofile.parse('<profile1> <profile2>')
        b = PackageBuildprofile.parse('<!profile3>')
        a.intersection_update(b)
        assert str(a) == '<profile1 !profile3> <profile2 !profile3>'

    def test_intersection_update_empty(self) -> None:
        a = PackageBuildprofile.parse('')
        b = PackageBuildprofile.parse('<!profile3>')
        a.intersection_update(b)
        assert str(a) == '<!profile3>'

    def test_str_entry_empty(self) -> None:
        a = PackageBuildprofile([PackageBuildprofileEntry()])
        assert str(a) == ''
