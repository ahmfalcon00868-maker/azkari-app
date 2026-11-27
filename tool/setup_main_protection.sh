#!/usr/bin/env bash
# تفعيل حماية فرع main على GitHub — يُشغّله مالك المستودع بتوكن يملك صلاحية
# Administration. توكن الوكيل الحالي يُرجع 403 (Resource not accessible).
#
# المبدأ: لا نضع أي فحص إلزامي غير موجود فعلاً على الفرع، وإلا تعطّلت كل عمليات
# الدمج نهائياً. الوضع الافتراضي يفرض "Analyze & Test" فقط.
#
# الاستخدام:
#   GH_TOKEN=<توكن المالك> ./tool/setup_main_protection.sh
#   GH_TOKEN=<توكن المالك> ./tool/setup_main_protection.sh --with-freeze
#   INCLUDE_FREEZE=1 GH_TOKEN=... ./tool/setup_main_protection.sh
#   DRY_RUN=1 ./tool/setup_main_protection.sh          # طباعة الحمولة فقط
#
# خيار --with-freeze يضيف "Freeze guard (no user-facing updates)" بشرط:
#   1) وجود .github/workflows/release_guard.yml على الفرع المستهدف.
#   2) وجود تشغيل ناجح (conclusion=success) لهذا الفحص على الفرع المستهدف.
# وإلا يتوقف السكربت بدل تفعيل شرط مستحيل.
set -euo pipefail

REPO="${REPO:-ahmfalcon00868-maker/azkari-app}"
BRANCH="${BRANCH:-main}"
DRY_RUN="${DRY_RUN:-0}"
INCLUDE_FREEZE="${INCLUDE_FREEZE:-0}"

CHECK_ANALYZE="Analyze & Test"
CHECK_FREEZE="Freeze guard (no user-facing updates)"
FREEZE_WORKFLOW=".github/workflows/release_guard.yml"

for arg in "$@"; do
  case "$arg" in
    --with-freeze) INCLUDE_FREEZE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,25p' "$0"
      exit 0
      ;;
    *)
      echo "وسيط غير معروف: $arg" >&2
      exit 2
      ;;
  esac
done

# حالة آخر تشغيل لفحص باسم محدّد على الفرع (فارغ = غير موجود).
check_state() {
  local name="$1"
  gh api "repos/$REPO/commits/$BRANCH/check-runs?per_page=100" 2>/dev/null |
    python3 -c '
import json, sys
name = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit
for run in data.get("check_runs", []):
    if run.get("name") == name and run.get("conclusion"):
        print(run["conclusion"])
        break
else:
    print("")
' "$name"
}

echo "→ المستودع: $REPO · الفرع: $BRANCH"

# 1) الفحص الإلزامي الأساسي: يجب أن يكون موجوداً على الفرع فعلاً.
ANALYZE_STATE="$(check_state "$CHECK_ANALYZE")"
if [ -z "$ANALYZE_STATE" ]; then
  cat >&2 <<EOF
✗ الفحص "$CHECK_ANALYZE" لم يُرصد على $BRANCH.
  إضافته كشرط إلزامي الآن ستقفل كل عمليات الدمج.
  الحل: شغّل workflow "Code checks" على $BRANCH مرة واحدة، ثم أعد المحاولة.
EOF
  exit 1
fi
echo "  ✓ $CHECK_ANALYZE (آخر نتيجة: $ANALYZE_STATE)"

CHECKS_JSON="[{\"context\": \"$CHECK_ANALYZE\"}"

# 2) حرس التجميد: اختياري وبتحقق مسبق.
if [ "$INCLUDE_FREEZE" = "1" ]; then
  if ! gh api "repos/$REPO/contents/$FREEZE_WORKFLOW?ref=$BRANCH" >/dev/null 2>&1; then
    echo "✗ $FREEZE_WORKFLOW غير موجود على $BRANCH — لن نضيف "$CHECK_FREEZE" كشرط إلزامي." >&2
    exit 1
  fi
  FREEZE_STATE="$(check_state "$CHECK_FREEZE")"
  if [ "$FREEZE_STATE" != "success" ]; then
    cat >&2 <<EOF
✗ آخر تشغيل للفحص "$CHECK_FREEZE" على $BRANCH ليس ناجحاً (الحالة: "${FREEZE_STATE:-غير موجود}").
  لا نضيفه كشرط إلزامي قبل نجاحه، وإلا تعطّلت عمليات الدمج.
  الحل: شغّل workflow "Release guard" على $BRANCH حتى ينجح، ثم أعد المحاولة.
EOF
    exit 1
  fi
  echo "  ✓ $CHECK_FREEZE (success)"
  CHECKS_JSON+=", {\"context\": \"$CHECK_FREEZE\"}"
else
  echo "  • $CHECK_FREEZE غير مُفعّل كشرط (فعّله بـ --with-freeze بعد وصول الـ workflow إلى $BRANCH)."
fi

CHECKS_JSON+="]"

PAYLOAD=$(cat <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": [],
    "checks": $CHECKS_JSON
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
)

echo "→ الحمولة:"
echo "$PAYLOAD"

if [ "$DRY_RUN" = "1" ]; then
  echo "→ DRY_RUN=1: لم يُرسَل أي تعديل."
  exit 0
fi

echo "→ تفعيل حماية $BRANCH ..."
gh api --method PUT "repos/$REPO/branches/$BRANCH/protection" \
  -H "Accept: application/vnd.github+json" \
  --input - <<<"$PAYLOAD"

echo "→ الحالة النهائية:"
gh api "repos/$REPO/branches/$BRANCH" \
  -q '{protected: .protection.enabled, checks: .protection.required_status_checks.checks}'
