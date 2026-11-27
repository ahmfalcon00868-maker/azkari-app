#!/usr/bin/env bash
# تفعيل حماية فرع main على GitHub — يُشغّله مالك المستودع بتوكن يملك صلاحية
# Administration (لا يعمل بتوكن الوكيل الحالي: يرجع 403).
#
# الاستخدام:
#   GH_TOKEN=<توكن المالك> ./tool/setup_main_protection.sh
set -euo pipefail

REPO="${REPO:-ahmfalcon00868-maker/azkari-app}"
BRANCH="${BRANCH:-main}"

# أسماء فحوصات الحالة الفعلية في هذا المستودع:
#   - "Analyze & Test"                     (workflow: Code checks)
#   - "Freeze guard (no user-facing updates)" (workflow: Release guard)
# ملاحظة: لا تُضِف "Freeze guard" كشرط إلزامي قبل أن يوجد release_guard.yml
# على main، وإلا تعطّلت كل عمليات الدمج.
CHECKS_JSON='[
  {"context": "Analyze & Test"},
  {"context": "Freeze guard (no user-facing updates)"}
]'

PAYLOAD=$(cat <<JSON
{
  "required_status_checks": {"strict": true, "contexts": [], "checks": $CHECKS_JSON},
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

echo "→ تفعيل حماية $BRANCH في $REPO ..."
gh api --method PUT "repos/$REPO/branches/$BRANCH/protection" \
  -H "Accept: application/vnd.github+json" \
  --input - <<<"$PAYLOAD"

echo "→ الحالة النهائية:"
gh api "repos/$REPO/branches/$BRANCH" -q '{protected: .protection.enabled, checks: .protection.required_status_checks.checks}'
