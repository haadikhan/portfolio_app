import "dart:typed_data";

import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

String _sanitizePdfText(String text) {
  return text
      .replaceAll("\u2014", "-") // em dash → hyphen
      .replaceAll("\u2013", "-") // en dash → hyphen
      .replaceAll("\u2022", "*") // bullet → asterisk
      .replaceAll("\u2713", "[x]") // [x] check mark → [x]
      .replaceAll("\u2714", "[x]") // [x] heavy check → [x]
      .replaceAll("\u00e9", "e") // é → e (safety)
      .replaceAll("\u201c", '"') // left double quote
      .replaceAll("\u201d", '"') // right double quote
      .replaceAll("\u2018", "'") // left single quote
      .replaceAll("\u2019", "'"); // right single quote
}

/// Inputs for a consent record PDF: agreement text plus acceptance proof.
class ConsentAgreementPdfInput {
  const ConsentAgreementPdfInput({
    required this.documentTitle,
    required this.agreementParagraphs,
    required this.userId,
    required this.agreementVersion,
    required this.acceptedAtLabel,
    required this.appVersion,
    required this.deviceName,
    required this.platform,
    required this.deviceHash,
  });

  final String documentTitle;
  final List<String> agreementParagraphs;
  final String userId;
  final String agreementVersion;
  final String acceptedAtLabel;
  final String appVersion;
  final String deviceName;
  final String platform;
  final String deviceHash;
}

const _kAgreementTitleLine1 = "Investor Participation Agreement";
const _kAgreementTitleLine2 = "Amanah Multi Asset Portfolio";

const _kAgreementParagraphs = <String>[
  """ARTICLE 1 - PURPOSE OF THIS AGREEMENT

This Agreement governs the Investor's voluntary participation in the Amanah Multi Asset Portfolio and establishes the rights, responsibilities, disclosures, procedures, fees, risks, and operational framework applicable to such participation.

The Investor acknowledges that participation is based upon private contractual arrangements and voluntary consent.

ARTICLE 2 - NATURE OF THE PORTFOLIO

The Investor acknowledges and agrees that:
- Amanah Multi Asset Portfolio is a private investment arrangement.
- The Portfolio is available only to approved participants, invited investors, private clients, and existing members.
- The Portfolio is not offered to the general public.
- The Portfolio is not represented as a publicly offered mutual fund.
- The Portfolio is operated through private participation arrangements among consenting parties.
- Participation in the Portfolio is entirely voluntary.

ARTICLE 3 - PORTFOLIO OBJECTIVES

The Portfolio seeks to achieve:
- Capital Growth
- Capital Preservation Objectives
- Income Generation
- Portfolio Diversification
- Long-Term Wealth Creation

The Investor understands that these objectives represent investment goals only and are not guarantees.

ARTICLE 4 - INVESTMENT MARKETS

The Portfolio may provide opportunities in the following asset classes:
A. Equity Market - Investment in KMI-30 and other approved equity securities.
B. Asset Market - Digital Gold and gold-backed investment opportunities.
C. Technology Market - Selected digital assets and technology-related investment opportunities.
D. Debt Market - Ijara Sukuk, Islamic Certificates, and approved Islamic fixed-income instruments.
E. Money Market - Cash, Islamic bank deposits, cash equivalents, and liquidity management instruments.""",
  """ARTICLE 5 - INVESTOR PARTICIPATION MODEL

The Investor acknowledges:
- Investment decisions remain subject to Investor approval.
- Portfolio Management Team may recommend allocations and investment opportunities.
- Investor retains the right to approve, reject, or request modifications to proposed allocations.
- No allocation shall be executed without Investor approval unless separate written discretionary authority has been granted.

ARTICLE 6 - CUSTODY OF FUNDS

The Investor acknowledges that:
- ISC acts as custodian and operational facilitator for investor funds.
- Investor funds may be held, administered, and processed through ISC operational systems.
- Custody arrangements are intended to enhance administration, record keeping, reporting, and operational efficiency.
- Custody arrangements do not constitute a guarantee of profits or returns.
- ISC shall maintain reasonable operational controls designed to safeguard investor funds.

ARTICLE 7 - CAPITAL PRESERVATION DISCLOSURE

The Investor acknowledges:
- The Portfolio seeks to preserve capital through prudent investment management practices.
- Neither ISC nor the Portfolio Management Team provides a legally enforceable guarantee of principal.
- Neither ISC nor the Portfolio Management Team guarantees future profits.
- Portfolio values may fluctuate.
- Market conditions may impact portfolio performance.

ARTICLE 8 - FEES AND CHARGES

8.1 Front-End Processing Fee: 2%
Purpose: Onboarding, Processing, Administration, Capital deployment.
The fee shall be deducted at the time of deposit.

8.2 Portfolio Management Fee: 1.5% per annum
Purpose: Research, Monitoring, Administration, Reporting, Portfolio oversight.
The fee may be accrued periodically.

8.3 Performance Participation Fee: 15% of eligible net profits.
The fee shall only apply to realized profits according to the Portfolio's performance methodology.

8.4 Referral Commission: Up to 1% may be paid from Portfolio revenues or front-end fees to approved referral partners. No separate recurring referral charge shall be imposed upon Investors.

8.5 Fee Amendments: Fee changes shall require prior notice through the Platform.""",
  """ARTICLE 9 - WITHDRAWAL POLICY

The Investor may request withdrawal at any time through the Platform. Withdrawal requests shall be processed subject to asset liquidity, settlement requirements, operational processing, and compliance verification.

Partial withdrawals may be processed according to Portfolio liquidity conditions and operational policies.

Notice Period: Any amount not immediately withdrawable shall become payable upon completion of the applicable notice period. Current notice period: 45 Days.

The Portfolio Management Team reserves the right to adjust operational withdrawal procedures where necessary for liquidity management.

ARTICLE 10 - INVESTMENT RISKS

The Investor acknowledges the existence of:
- Market Risk - Market prices may rise or fall.
- Equity Risk - Share prices may fluctuate.
- Gold Risk - Gold prices may experience volatility.
- Digital Asset Risk - Digital assets may experience significant price fluctuations.
- Credit Risk - Issuers of Sukuk or Certificates may experience financial difficulties.
- Liquidity Risk - Certain assets may require time to liquidate.
- Regulatory Risk - Changes in laws or regulations may impact investments.
- Technology Risk - System interruptions may occur.

ARTICLE 11 - NO GUARANTEE

No representation has been made guaranteeing profits, specific returns, portfolio performance, or future appreciation. Participation involves investment risk.

ARTICLE 12 - SHARIAH POSITION

The Portfolio seeks to follow Shariah-compliant and Shariah-inspired investment principles. Investment screening methodologies may be applied to investment selection. The Investor understands that interpretations of Shariah principles may differ among scholars and institutions.

ARTICLE 13 - AML & SOURCE OF FUNDS DECLARATION

The Investor represents that funds originate from lawful sources, the Investor is the beneficial owner of invested funds, information provided is accurate, and the Investor shall provide documents reasonably requested for verification. The Portfolio Management Team reserves the right to reject, suspend, or terminate participation where AML concerns arise.""",
  """ARTICLE 14 - PRIVACY AND DATA PROTECTION

The Investor authorizes the collection, storage, processing, and use of information necessary for account administration, reporting, compliance, and operational management. Information shall be treated confidentially except where disclosure is required by law, regulatory authority, court order, or compliance obligations.

ARTICLE 15 - DIGITAL PLATFORM TERMS

The Investor understands that the Platform is an information and management portal. Portfolio values displayed may be subject to timing and reporting adjustments. Temporary technical interruptions may occur. The Investor is responsible for safeguarding login credentials.

ARTICLE 16 - LIMITATION OF LIABILITY

Neither ISC, Amanah Multi Asset Portfolio, partners, officers, employees, consultants, agents, nor affiliates shall be liable for market losses, investment underperformance, economic conditions, regulatory changes, force majeure events, or third-party failures - except where liability results directly from proven fraud, willful misconduct, or gross negligence.

ARTICLE 17 - INDEMNITY

The Investor agrees to indemnify and hold harmless the Portfolio Management Team from losses resulting from false information supplied by the Investor, breach of this Agreement, or unlawful activities conducted by the Investor.

ARTICLE 18 - DISPUTE RESOLUTION

The Parties shall first attempt amicable resolution of disputes. Where resolution is not achieved, disputes shall be submitted to arbitration in accordance with applicable laws of Pakistan. The seat of arbitration shall be determined by the Portfolio Management Team unless otherwise agreed.

ARTICLE 19 - GOVERNING LAW

This Agreement shall be governed and interpreted in accordance with the laws of the Islamic Republic of Pakistan.

ARTICLE 20 - ELECTRONIC ACCEPTANCE

Electronic acceptance through the Platform shall constitute valid and binding consent. Records maintained shall include: Name, Investor ID, Date, Time, Device Information, IP Address, and Agreement Version. Such records shall constitute evidence of acceptance.

ARTICLE 21 - ENTIRE AGREEMENT

This Agreement, together with Risk Disclosures, Fee Schedule, Withdrawal Policy, Privacy Policy, and Platform Terms constitutes the entire understanding between the Parties.""",
  """INVESTOR RISK ACKNOWLEDGEMENT & LIABILITY CONSENT

I acknowledge and understand that:
[x] Investments involve risk.
[x] Portfolio values may fluctuate.
[x] Profits are not guaranteed.
[x] Market losses may occur.
[x] Investment opportunities may perform below expectations.
[x] Digital asset investments may experience significant volatility.
[x] Equity investments may decline in value.
[x] Gold prices may fluctuate.
[x] Sukuk and certificate investments may be affected by issuer or market conditions.
[x] Liquidity restrictions may temporarily impact withdrawals.

I further acknowledge that the Portfolio Manager, ISC, partners, officers, employees, representatives, and affiliates shall not be responsible for ordinary market losses resulting from investment activities carried out in good faith.

INVESTOR PARTICIPATION AGREEMENT - FINAL CONFIRMATION

By accepting this Agreement, the Investor confirms that:
[x] I have read and understood this Agreement in full.
[x] I am participating voluntarily in the Amanah Multi Asset Portfolio.
[x] I understand the Portfolio is a private investment arrangement and not a publicly offered mutual fund.
[x] I have independently evaluated the suitability of participation.
[x] I understand that investment values may fluctuate and that profits are not guaranteed.
[x] I authorize the Portfolio Management Team to present investment opportunities and allocation recommendations.
[x] I retain final authority regarding allocation decisions.
[x] I confirm that all funds invested are legally owned by me and originate from lawful sources.
[x] I accept all applicable fees, charges, notices, and withdrawal policies disclosed by the Platform.
[x] I understand that no guarantee of future profits, returns, or performance has been provided.

PRIVATE PORTFOLIO DISCLOSURE STATEMENT

The Amanah Multi Asset Portfolio is a privately managed investment arrangement operated for invited investors, existing members, private clients, and approved participants. It is not a publicly offered mutual fund and is not offered to the general public. Participation is voluntary and based solely upon the Investor's own decision after reviewing all disclosures, risks, policies, and agreements.

This Agreement shall become legally effective upon digital acceptance through the Platform.""",
];

pw.Widget _proofRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(
            _sanitizePdfText(label),
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            _sanitizePdfText(value),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    ),
  );
}

/// Builds an A4 PDF with the legal agreement body and stored acceptance proof.
Future<Uint8List> buildConsentAgreementPdf(ConsentAgreementPdfInput input) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        pw.Text(
          _sanitizePdfText(_kAgreementTitleLine1),
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          _sanitizePdfText(_kAgreementTitleLine2),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        for (final paragraph in _kAgreementParagraphs) ...[
          pw.Text(
            _sanitizePdfText(paragraph),
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
          ),
          pw.SizedBox(height: 10),
        ],
        pw.SizedBox(height: 20),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 12),
        pw.Text(
          _sanitizePdfText("Acceptance Record"),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        _proofRow("Investor UID", input.userId),
        _proofRow("Agreement Version", input.agreementVersion),
        _proofRow("Date & Time", input.acceptedAtLabel),
        _proofRow("App Version", input.appVersion),
        _proofRow("Device", input.deviceName),
        _proofRow("Platform", input.platform),
        _proofRow("Device ID", input.deviceHash),
      ],
    ),
  );

  return pdf.save();
}
