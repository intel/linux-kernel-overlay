From 1148ec2bc2c7462f647ed8e1b92795509ce3c76e Mon Sep 17 00:00:00 2001
From: Qiang Rao <qiang.rao@intel.com>
Date: Thu, 22 Jul 2021 19:57:18 +0800
Subject: [PATCH 11/23] Enable support to read a few whitelisted registers.

After CONFIG_IO_STRICT_DEVMEM is enabled in kernel config,
some registers cannot be read via /dev/mem anymore. This
patch provides support to application which need to read
back a few whitelisted registers.

Signed-off-by: Qiang Rao <qiang.rao@intel.com>
---
 drivers/tcc/tcc_buffer.c | 122 ++++++++++++++++++++++++++++++++++++++-
 drivers/tcc/tcc_buffer.h |  99 ++++++++++++++++++++++++++++++-
 2 files changed, 217 insertions(+), 4 deletions(-)

diff --git a/drivers/tcc/tcc_buffer.c b/drivers/tcc/tcc_buffer.c
index fbdab419a241..b70cb689930d 100644
--- a/drivers/tcc/tcc_buffer.c
+++ b/drivers/tcc/tcc_buffer.c
@@ -61,12 +61,23 @@
 #include <linux/list.h>
 #include <linux/mm.h>
 #include <linux/module.h>
-#include <linux/types.h>
 #include <linux/version.h>
-
 #include <linux/init.h>
+#include <asm/intel-family.h>
 #include "tcc_buffer.h"
 
+/*
+ * This driver supports two versions of configuration tables.
+ *
+ * Some terminologies between these two versions are different.
+ * a) In first version, the sram with cache locking is named as pseodu sram (PSRAM);
+ *    In second version, the sram with cache locking is named as software sram (SSRAM);
+ * b) In first version, configuration table is named as PTCT;
+ *    In second version, configuration table is named as RTCT;
+ *
+ * This driver continues using the terminologies defined in first version.
+ */
+
 static int tccdbg;
 module_param(tccdbg, int, 0644);
 MODULE_PARM_DESC(tccdbg, "Turn on/off trace");
@@ -875,12 +886,58 @@ static int tcc_buffer_mmap(struct file *f, struct vm_area_struct *vma)
 		return 0;
 }
 
+static int register_address_is_allowed(u64 base, u64 offset)
+{
+	/* check if phyaddr is within the whitelist range */
+	u32 len = 0;
+
+	if (offset >= TCC_REG_MAX_OFFSET)
+		return 0;
+
+	switch (boot_cpu_data.x86_model) {
+	case INTEL_FAM6_TIGERLAKE:
+		/* TGL-H */
+		for (len = 0; len < ARRAY_SIZE(tcc_registers_wl_tglh); len++) {
+			if ((tcc_registers_wl_tglh[len].base == base) && (tcc_registers_wl_tglh[len].offset == offset)) {
+				dprintk("{base %016llx, offset %016llx} is in the tglh whitelist.\n", base, offset);
+				return 1;
+			}
+		}
+	break;
+	case INTEL_FAM6_TIGERLAKE_L:
+		/* TGL-U */
+		for (len = 0; len < ARRAY_SIZE(tcc_registers_wl_tglu); len++) {
+			if ((tcc_registers_wl_tglu[len].base == base) && (tcc_registers_wl_tglu[len].offset == offset)) {
+				dprintk("{base %016llx, offset %016llx} is in the tglu whitelist.\n", base, offset);
+				return 1;
+			}
+		}
+	break;
+	case INTEL_FAM6_ATOM_TREMONT:
+		/* EHL */
+		for (len = 0; len < ARRAY_SIZE(tcc_registers_wl_ehl); len++) {
+			if ((tcc_registers_wl_ehl[len].base == base) && (tcc_registers_wl_ehl[len].offset == offset)) {
+				dprintk("{base %016llx, offset %016llx} is in the ehl whitelist.\n", base, offset);
+				return 1;
+			}
+		}
+	break;
+	default:
+		pr_err("No whitelisted register.");
+	break;
+	}
+	return 0;
+}
+
 static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
 {
 	int ret = 0;
 	struct psram *p_psram;
 	struct tcc_buf_mem_config_s memconfig;
 	struct tcc_buf_mem_req_s req_mem;
+	struct tcc_register_s tcc_register;
+	u64 register_phyaddr;
+	void *register_data = NULL;
 
 	int cpu, testmask = 0;
 
@@ -996,6 +1053,67 @@ static long tcc_buffer_ioctl(struct file *filp, unsigned int cmd, unsigned long
 		if (ret != 0)
 			return -EFAULT;
 
+		break;
+	case TCC_GET_REGISTER:
+		if (NULL == (struct tcc_register_s *)arg) {
+			pr_err("arg from user is nullptr!");
+			return -EINVAL;
+		}
+
+		ret = copy_from_user(&tcc_register, (struct tcc_register_s *)arg,
+							sizeof(struct tcc_register_s));
+		if (ret != 0)
+			return -EFAULT;
+
+		if (tcc_register.e_format == TCC_MMIO32) {
+			if ((tcc_register.info.mmio32.base <= (UINT_MAX - TCC_REG_MAX_OFFSET)) && (tcc_register.info.mmio32.addr <= TCC_REG_MAX_OFFSET)) {
+				if (register_address_is_allowed((u64)(tcc_register.info.mmio32.base), (u64)(tcc_register.info.mmio32.addr)) == 0) {
+					pr_err("this register is not allowed to read!");
+					return -EINVAL;
+				}
+			} else {
+				pr_err("Invalid mmio32 register base/addr provided.");
+				return -EINVAL;
+			}
+			register_phyaddr = (u64)(tcc_register.info.mmio32.base + tcc_register.info.mmio32.addr);
+			dprintk("register_phyaddr        0x%016llx\n", register_phyaddr);
+			register_data = memremap(register_phyaddr, sizeof(int), MEMREMAP_WB);
+			if (!register_data) {
+				pr_err("cannot map this address");
+				return -ENOMEM;
+			}
+			tcc_register.info.mmio32.data = (*(int *)(register_data)) & tcc_register.info.mmio32.mask;
+			dprintk("mmio32.data   u32 value 0x%08x\n", tcc_register.info.mmio32.data);
+			memunmap(register_data);
+		} else if (tcc_register.e_format == TCC_MMIO64) {
+			if ((tcc_register.info.mmio64.base <= (ULONG_MAX - TCC_REG_MAX_OFFSET)) && (tcc_register.info.mmio64.addr <= TCC_REG_MAX_OFFSET)) {
+				if (register_address_is_allowed(tcc_register.info.mmio64.base, tcc_register.info.mmio64.addr) == 0) {
+					pr_err("this register is not allowed to read!");
+					return -EINVAL;
+				}
+			} else {
+				pr_err("Invalid mmio64 register base/addr provided.");
+				return -EINVAL;
+			}
+			register_phyaddr = (u64)(tcc_register.info.mmio64.base + tcc_register.info.mmio64.addr);
+			dprintk("register_phyaddr        0x%016llx\n", register_phyaddr);
+			register_data = memremap(register_phyaddr, sizeof(long), MEMREMAP_WB);
+			if (!register_data) {
+				pr_err("cannot map this address");
+				return -ENOMEM;
+			}
+			tcc_register.info.mmio64.data = (*(long *)(register_data)) & tcc_register.info.mmio64.mask;
+			dprintk("mmio64.data   u64 value 0x%016llx\n", tcc_register.info.mmio64.data);
+			memunmap(register_data);
+		} else {
+			pr_err("Invalid or unsupported format!");
+			return -EINVAL;
+		}
+
+		ret = copy_to_user((struct tcc_register_s *)arg, &tcc_register, sizeof(struct tcc_register_s));
+		if (ret != 0)
+			return -EFAULT;
+
 		break;
 	default:
 		return -ENOIOCTLCMD;
diff --git a/drivers/tcc/tcc_buffer.h b/drivers/tcc/tcc_buffer.h
index 90ae36c62fe2..3fe446173fcb 100644
--- a/drivers/tcc/tcc_buffer.h
+++ b/drivers/tcc/tcc_buffer.h
@@ -53,13 +53,15 @@
  *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  *  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  */
-
+#include <linux/types.h>
 #include <linux/ioctl.h>
 
 /* TCC Device Interface */
 #define TCC_BUFFER_NAME  "/tcc/tcc_buffer"
 #define UNDEFINED_DEVNODE 256
 
+#define TCC_REG_MAX_OFFSET 0x100000
+
 /* IOCTL MAGIC number */
 #define IOCTL_TCC_MAGIC   'T'
 
@@ -105,12 +107,101 @@ struct tcc_buf_mem_req_s {
 	unsigned int devnode;
 };
 
+/* This structure defines the whitelisted register for mmio read */
+struct tcc_registers_wl_s {
+	u64 base;
+	u64 offset;
+};
+
+struct tcc_registers_wl_s tcc_registers_wl_ehl[] = {
+	{0xFEDA0000, 0x0A78},
+};
+
+struct tcc_registers_wl_s tcc_registers_wl_tglu[] = {
+	{ 0xFEDA0000, 0x0A78},
+	{ 0xFEDC0000, 0x6F08},
+	{ 0xFEDC0000, 0x6F10},
+	{ 0xFEDC0000, 0x6F00}
+};
+
+struct tcc_registers_wl_s tcc_registers_wl_tglh[] = {
+	{ 0xFEDA0000, 0x0A78}
+};
+
+/* enum type for tcc_register structure */
+enum TCC_REG_PHASE {
+	TCC_PRE_MEM        = 0x00000000,
+	TCC_POST_MEM       = 0x00000001,
+	TCC_LATE_INIT      = 0x00000002,
+	TCC_INVALID_PHASE  = 0xFFFFFFFF
+};
+
+enum TCC_REG_FORMAT {
+	TCC_MMIO32         = 0x00000000,
+	TCC_MMIO64         = 0x00000001,
+	TCC_MSR            = 0x00000002,
+	TCC_IOSFSB         = 0x00000003,
+	TCC_MAILBOX        = 0x00000004,
+	TCC_INVALID_FORMAT = 0xFFFFFFFF
+};
+
+enum TCC_IOSFSB_NETWORK {
+	TCC_IOSFSB_CPU     = 0x00000000,
+	TCC_IOSFSB_PCH     = 0x00000001
+};
+
+enum TCC_MAILBOX_TYPE {
+	TCC_MAILBOX_SA     = 0x00000000,
+	TCC_MAILBOX_MSR    = 0x00000001
+};
+
+/* Support mmio32 and mmio64 formats only. */
+struct tcc_register_s {
+	enum TCC_REG_PHASE e_phase;     /* IN: enum'd above */
+	enum TCC_REG_FORMAT e_format;   /* IN: enum'd above, determines which structure format to use */
+	union {
+		struct {
+			u32 base;               /* IN: ECAM format B:D:F:R of BAR (add this to ECAM_BASE) */
+			u32 addr;               /* IN: offset from BAR */
+			u32 mask;               /* IN: data bit-mask (1's are valid) */
+			u32 data;               /* OUT: data value */
+		} mmio32;
+		struct {
+			u64 base;               /* IN: ECAM format B:D:F:R of BAR (add this to ECAM_BASE) */
+			u64 addr;               /* IN: offset from BAR */
+			u64 mask;               /* IN: data bit-mask (1's are valid) */
+			u64 data;               /* OUT: data value */
+		} mmio64;
+		struct {
+			u32 apic_id;            /* IN: APIC ID of logical CPU corresponding to this MSR value */
+			u32 addr;               /* IN: ECX value */
+			u64 mask;               /* IN: EDX:EAX data bit-mask (1's are valid) */
+			u64 data;               /* OUT: EDX:EAX data value */
+		} msr;
+		struct {
+			enum TCC_IOSFSB_NETWORK e_iosfsb_network; /* IN: which IOSFSB network to use */
+			u8 port;                /* IN: IOSFSB Port ID */
+			u8 type;                /* IN: IOSFSB Register Type (Command) */
+			u32 addr;               /* IN: register address */
+			u32 mask;               /* IN: data bit-mask (1's are valid) */
+			u32 data;               /* IN: data value */
+		} iosfsb;
+		struct {
+			enum TCC_MAILBOX_TYPE e_type;   /* IN: Mailbox type */
+			u32 addr;               /* IN: register address */
+			u32 mask;               /* IN: data bit-mask (1's are valid) */
+			u32 data;               /* OUT: data value */
+		} mailbox;
+	} info;
+};
+
 enum ioctl_index {
 	IOCTL_TCC_GET_REGION_COUNT = 1,
 	IOCTL_TCC_GET_MEMORY_CONFIG,
 	IOCTL_TCC_REQ_BUFFER,
 	IOCTL_TCC_QUERY_PTCT_SIZE,
-	IOCTL_TCC_GET_PTCT
+	IOCTL_TCC_GET_PTCT,
+	IOCTL_TCC_GET_REGISTER
 };
 
 /*
@@ -138,3 +229,7 @@ enum ioctl_index {
  */
 #define TCC_REQ_BUFFER _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_REQ_BUFFER, struct tcc_buf_mem_req_s *)
 
+/*
+ * User to get TCC Register
+ */
+#define TCC_GET_REGISTER _IOWR(IOCTL_TCC_MAGIC, IOCTL_TCC_GET_REGISTER, struct tcc_register_s *)
-- 
2.25.1

