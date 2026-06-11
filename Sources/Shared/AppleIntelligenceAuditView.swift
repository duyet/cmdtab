import SwiftUI

// MARK: - Apple Intelligence Audit View
/// Renders the on-device readiness audit as a compact checklist: one row per
/// finding with a status icon, title, explanation, and (when fixable) a
/// one-click button that opens the right System Settings pane.
///
/// Used both in Settings (full panel) and in the composer "Learn more" popover.
struct AppleIntelligenceAuditView: View {
    /// Recomputed each time the view appears so it reflects live availability.
    let findings: [AIAuditFinding]
    /// Compact mode trims padding/typography for the composer popover.
    var compact: Bool = false

    init(findings: [AIAuditFinding] = AppleIntelligenceAudit.current, compact: Bool = false) {
        self.findings = findings
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            ForEach(findings) { finding in
                row(finding)
                if finding.id != findings.last?.id {
                    Divider().opacity(0.4)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ finding: AIAuditFinding) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon(finding.status))
                .font(.system(size: compact ? 12 : 14))
                .foregroundColor(color(finding.status))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(finding.title)
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(finding.detail)
                    .font(.system(size: compact ? 11 : 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let fix = finding.fix {
                    Button(fix.buttonLabel) { fix.open() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(color(finding.status))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func icon(_ status: AIAuditFinding.Status) -> String {
        switch status {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .blocked: return "xmark.octagon.fill"
        }
    }

    private func color(_ status: AIAuditFinding.Status) -> Color {
        switch status {
        case .ok: return .green
        case .warning: return .orange
        case .blocked: return .red
        }
    }
}
