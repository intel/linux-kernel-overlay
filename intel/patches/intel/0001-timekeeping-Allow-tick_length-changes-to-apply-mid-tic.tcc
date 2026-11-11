From 1246d680032e9657a3585c5a49ce1aaad977ce6d Mon Sep 17 00:00:00 2001
From: David Woodhouse <dwmw@amazon.co.uk>
Date: Thu, 5 Nov 2026 19:08:50 -0800
Subject: [PATCH] timekeeping: Allow tick_length changes to apply mid-tick
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit

When the NTP tick length changes, timekeeping_apply_adjustment() applies
the accounting for the new rate to ntp_error retrospectively for the
partial tick which is currently in progress. So the ideal line of the
clock conceptually changes from the moment of cycle_last (which can be
almost a full tick ago), and ntp_error grows to show the difference
between that and what userspace actually saw already.

Commit c2cda2a5bda9 ("timekeeping/ntp: Don't align NTP frequency
adjustments to ticks") removed the equivalent alignment term from the
old accounting in 2018, precisely so that a new frequency took effect
at the time of the update. Commit b7befd6d9120 ("timekeeping: Account
for monotonicity adjustment in ntp_error") effectively reinstated the
alignment, because *some* accounting is needed at that point — the
same retrospective mult change also carries the dither and skew
components, whose divergence genuinely does belong in ntp_error.

This can lead to a significant value (10s of microseconds) landing in
ntp_error which can take *days* to drain through the natural mult ±1
dithering.

The slow-draining ntp_error then applies a consistent bias to that ±1
dithering, meaning that the precision of the effective frequency
requested by userspace is limited to integer 'mult' values, since the
dithering is no longer effective to achieve the fractional parts.

Jie Wang reports that this makes phc2sys take minutes instead of
seconds to settle CLOCK_REALTIME after a step of the PHC it follows:
the servo slews at up to 10% and then backs off by several percent per
second, charging tens of microseconds to ntp_error on every update. On
a gPTP setup (ptp4l + phc2sys on back-to-back i226 NICs, PREEMPT_RT),
the time for the phc2sys offset to settle below 100ns after a 1s step
of the grandmaster's PHC rose from ~32s to 200-400s or more. Yuan Wang
measured this patch alone restoring it to 32s across three consecutive
steps, with the steady-state lock (~8ns rms) unchanged.

Fix this by allowing the rate change to be conceptually applied at
'offset' into the partial tick, rather than the start of the tick.
This means that the amount of delta which gets accumulated into
ntp_error remains low.

Rather than factoring this into timekeeping_apply_adjustment() which
already makes my eyes bleed, pre-correct it when the rate changes, to
adjust the 'intended' clock position according to the delta between
old and new tick lengths (but leaving skew as it should be).

Fixes: b7befd6d9120 ("timekeeping: Account for monotonicity adjustment in ntp_error")
Reported-by: Jie Wang <jie.wang@intel.com>
Closes: https://lore.kernel.org/all/20261105032150.1763572-1-yuan1.wang@intel.com/
Cc: stable@vger.kernel.org
Acked-by: John Stultz <jstultz@google.com>
Signed-off-by: David Woodhouse <dwmw@amazon.co.uk>
---
 kernel/time/timekeeping.c | 34 ++++++++++++++++++++++++++++++++--
 1 file changed, 32 insertions(+), 2 deletions(-)

diff --git a/kernel/time/timekeeping.c b/kernel/time/timekeeping.c
index ea2e6e55f37b..ad5a49aa0cbd 100644
--- a/kernel/time/timekeeping.c
+++ b/kernel/time/timekeeping.c
@@ -2433,6 +2433,7 @@ static void timekeeping_adjust(struct timekeeper *tk, s64 offset)
 {
 	u64 ntp_tl = ntp_tick_length(tk->id);
 	s64 skew = ntp_get_skew_delta(tk->id);
+	u64 dividend;
 	u32 mult;
 
 	/*
@@ -2444,6 +2445,8 @@ static void timekeeping_adjust(struct timekeeper *tk, s64 offset)
 		/* Revert to the base mult rate. */
 		mult = tk->tkr_mono.mult - tk->ntp_err_mult;
 	} else {
+		u64 old_ntp_tick = tk->ntp_tick;
+
 		tk->ntp_tick = ntp_tl;
 		tk->skew_delta = skew;
 		/*
@@ -2451,8 +2454,35 @@ static void timekeeping_adjust(struct timekeeper *tk, s64 offset)
 		 * scale it back up to the full per-tick rate for the mult bias.
 		 */
 		skew *= NTP_INTERVAL_FREQ;
-		mult = div64_u64((tk->ntp_tick + skew) >> tk->ntp_error_shift,
-				 tk->cycle_interval);
+		dividend = (tk->ntp_tick + skew) >> tk->ntp_error_shift;
+		mult = div64_u64(dividend, tk->cycle_interval);
+
+		/*
+		 * In timekeeping_apply_adjustment(), the mult_adj value is
+		 * retrospectively applied as if it had come into effect at
+		 * the *start* of the current tick.  Any discrepancy due to
+		 * the fact that time has *actually* been counted at the old
+		 * mult rate between the start of the tick and now ('offset'
+		 * cycles into that tick) is dumped into ntp_error.
+		 *
+		 * When tick_length is changed by a large amount, that can
+		 * lead to tens of microseconds of ntp_error being accrued.
+		 *
+		 * Fix this by conceptually applying the tick_length change
+		 * now (at 'offset'), rather than the start of the tick.
+		 *
+		 * That means calculating what 'mult' would have been with
+		 * the old ntp_tick length (but the *current* value of skew),
+		 * and pre-adjusting ntp_error to compensate.
+		 */
+		if (tk->ntp_tick != old_ntp_tick) {
+			u64 old_dividend = (old_ntp_tick + skew) >> tk->ntp_error_shift;
+			s64 old_base_mult = div64_u64(old_dividend, tk->cycle_interval);
+			s64 mult_delta = (s64)mult - old_base_mult;
+
+			tk->ntp_error -= ((s64)offset * mult_delta)
+					 << tk->ntp_error_shift;
+		}
 	}
 
 	/*
-- 
2.43.0

