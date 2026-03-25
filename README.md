# Rule Loss Estimation Analysis

A Fraud Prevention rules review type analysis tool for optimizing CRM capacity for Payfac. This notebook analyzes historical fraud data to prioritize merchant review rules based on loss, precision, and volume metrics.

![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![Jupyter](https://img.shields.io/badge/jupyter-notebook-orange.svg)

## Overview

This analysis tool helps fraud prevention and CRM teams make data-driven decisions about resource allocation in Acquiring merchant review processes. By analyzing 6 months of historical fraud data, it identifies which merchant review rules generate the highest losses, evaluates their precision, and recommends optimal review types (Deep/Standard/Light) for each rule — all within a target weekly capacity constraint.

**Target Audience**: Fraud prevention, Acquiring risk operations teams (CRM).

## Features

- **Comprehensive 6-Month Fraud Loss Analysis** across 17 merchant review rules
- **Automated Loss Calculation** for both NOF (Notification of Fraud) and chargeback losses
- **Dual Precision Analysis** — both per-case precision and rule-level precision (L3M)
- **Priority Scoring System** with weighted metrics (50% loss, 30% precision, 20% volume)
- **Capacity-Constrained Review Type Optimization** — greedy algorithm assigns Deep/Standard/Light reviews while staying within a target weekly hours budget
- **Current State vs. Proposed State Comparison** with hours reduction analysis
- **Deduplication Logic** to ensure accurate per-merchant, per-rule analysis

## Repository Structure

```
CRM_Capacity_planning/
├── rule_loss_estimation_Analysis.ipynb   # Main analysis notebook
├── rule_precision_L3M.sql               # SQL query for rule precision (last 3 months)
└── README.md
```

## Prerequisites

### Technical Requirements

- **Python 3.12+**
- **Jupyter Notebook** or JupyterLab
- **Required Python Packages**:
  - `snowflake-snowpark-python` — Snowflake data warehouse connectivity
  - `pandas` — Data manipulation and analysis
  - `numpy` — Numerical computing

### Access Requirements

- **Snowflake Account Access** (Wise analytics warehouse)
- **Okta SSO Authentication** configured
- **Database Permissions** for:
  - `ANALYTICS_DB.DDCASE.DD_CASE` — Case management data
  - `ANALYTICS_DB.RPT_PRODUCT.PAY_WITH_CARD_MERCHANTS` — Merchant profiles
  - `ANALYTICS_DB.RPT_PRODUCT.PAY_WITH_CARD_PAYMENTS` — Payment transactions

## Installation

```bash
# Clone the repository
git clone [your-repository-url]
cd [repository-name]

# Install required packages
pip install -r requirements.txt

# Launch Jupyter
jupyter notebook
```

## Configuration

### Snowflake Connection Setup

Update the `connection_parameters` dictionary in the notebook with your credentials:

```python
connection_parameters = {
    "account": "your_account_identifier",  # Wise Snowflake account
    "user": "your_username",                # your Wise email
    "authenticator": "EXTERNALBROWSER",  # For Okta SSO, opens Okta in browser
    "warehouse": "ANALYSTS",
    "database": "ANALYTICS_DB"
}
```

**Security Note**: Never hardcode passwords or sensitive credentials in the notebook. The `EXTERNALBROWSER` authenticator will prompt for SSO login via your browser.

## Usage

1. **Open the Notebook**
   ```bash
   jupyter notebook rule_loss_estimation_Analysis.ipynb
   ```

2. **Update Connection Parameters**
   - Modify the `connection_parameters` dictionary with your Snowflake account details

3. **Run Cells Sequentially**
   - Execute cells in order from top to bottom
   - The analysis will fetch data for the last 6 months from the current date

4. **Review Key Outputs**
   - Loss estimation by rule
   - Summary statistics
   - Current state analysis (weekly hours, capacity gap)
   - Rule prioritization rankings (two scoring variants)
   - Proposed review type assignments within capacity budget

## Outputs

### 1. Loss Analysis Table

For each merchant review rule, the analysis provides:

| Metric | Description |
|--------|-------------|
| **Unique Merchants** | Count of distinct merchants flagged by the rule |
| **Total Payments** | Number of successful payment transactions post-review |
| **NOF Payments / Amount** | Notification of Fraud count and value (GBP) |
| **Chargeback Payments / Amount** | Chargeback count and value (GBP) |
| **Total Fraud** | Combined NOF + chargeback losses (GBP) |
| **Problematic Merchants** | Merchants with at least one NOF or chargeback |
| **Avg Fraud per Problematic Merchant** | Expected loss if a risky merchant goes unreviewed |

### 2. Current State Analysis

Calculates the current operational workload:
- Current monthly hours across all rules
- Conversion to weekly hours using the formula: `(monthly_hours * 12/52) + 20` (20h added for NOF/CB handling)
- Comparison against target weekly capacity (configurable, default 75h)
- Required reduction percentage

### 3. Priority Scoring (Two Variants)

Rules are scored and ranked using two precision inputs:

- **Per-case precision**: What percentage of individual case reviews result in an offboard/action
- **Rule precision (L3M)**: What percentage of merchants flagged by the rule over the last 3 months are genuinely problematic

Both variants use the same weighting:

```
priority_score = (0.5 * normalized_loss) + (0.3 * precision) + (0.2 * normalized_volume)
```

Where:
- `normalized_loss` = monthly avg fraud per problematic merchant / max across all rules, scaled to 0–100
- `precision` = either per-case or rule-level precision (0–100)
- `normalized_volume` = (cases × AHT) / max effort across all rules, scaled to 0–100

### 4. Review Type Recommendations

A greedy capacity-constrained algorithm assigns review types:

- **Deep Review** (~48 min): High-risk rules requiring comprehensive investigation
- **Standard Review** (~35 min): Moderate-risk rules with balanced investigation
- **Light Review** (15 min): Lower-risk patterns requiring quick checks

The algorithm:
1. Sorts rules by priority score (highest first)
2. Starts all rules at Light review (cheapest)
3. Iteratively upgrades the highest-priority rules to Standard, then Deep
4. Stops upgrading when the weekly capacity target would be exceeded
5. Respects constraints: a rule's proposed type cannot exceed its current type
6. Supports fixed/locked rules (e.g., `LTVHigherThresholdBreached` locked to Deep)

## Key Metrics Explained

| Metric | Definition | Business Impact |
|--------|------------|----------------|
| **NOF (Notification of Fraud)** | Confirmed fraud transactions | PSP impacts |
| **Chargeback Amount** | Customer dispute losses | Reputational and financial impact |
| **Total Fraud** | Combined NOF + chargeback losses | Overall rule effectiveness measure |
| **Per-case Precision %** | Cases resulting in action / total cases reviewed | Resource efficiency indicator |
| **Rule Precision % (L3M)** | Problematic merchants / total flagged merchants (last 3 months) | Rule quality indicator |
| **Priority Score** | Weighted composite metric (loss, precision, volume) | Resource allocation guide |
| **Avg Fraud per Problematic Merchant** | Expected loss if risky merchant isn't caught | Risk prioritization metric |

## Example Results

Based on actual analysis of 6 months of fraud data:

### Top Loss Rules

| Rule | Total Fraud (GBP) | Problematic Merchants | Avg Fraud/Merchant |
|------|-------------------:|----------------------:|-------------------:|
| AttemptedAmountExceedsTransferAmount | £45,978 | 2 | £22,989 |
| PaymentForRequestRecentlyPublished | £44,662 | 4 | £11,165 |
| AvgDailyPayFacTxnExceedsAvgDailyTransfer | £44,534 | 37 | £1,204 |
| Transaction_amount | £36,973 | 5 | £7,395 |
| Bin6AttemptedVolumeSpike | £19,382 | 11 | £1,762 |

### Summary Metrics

- **Total Fraud Across All Rules**: £222,818
- **Monthly Average Fraud**: £37,136
- **Unique Merchants Analyzed**: 2,619
- **Total Payments Processed**: 7,601

### Capacity Analysis

- **Current Weekly Hours**: ~104h
- **Target Weekly Hours**: 75h
- **Reduction Needed**: ~29h/week (28.1%)

## Methodology

### Analysis Approach

- **Time Window**: Last 6 months from current execution date
- **Case Type**: `ACQUIRING_MERCHANT_REVIEW` cases only
- **Case Status**: Only `CLOSED` cases included for complete outcome data
- **Deduplication Logic**: First case per profile-rule combination to avoid double-counting
- **Loss Calculation**: Post-review period losses tracked until merchant offboarding
- **Data Sources**:
  - Case data from `DDCASE.DD_CASE`
  - Merchant profiles from `RPT_PRODUCT.PAY_WITH_CARD_MERCHANTS`
  - Transaction data from `RPT_PRODUCT.PAY_WITH_CARD_PAYMENTS`

### Capacity Formula

Weekly hours are calculated using:

```
weekly_hours = ((total_monthly_minutes / 60) + 24.8) * (12/52) + 20
```

Where:
- `total_monthly_minutes` = sum of (cases per month × handling time per case) across all rules
- `24.8` = additional monthly overhead hours
- `12/52` = conversion from monthly to weekly
- `20` = fixed weekly hours for NOF and chargeback handling

### Priority Score Calculation

```python
priority_score = (0.5 * normalized_loss) + (0.3 * precision_rate) + (0.2 * normalized_volume)
```

## Customization

### Adjusting the Capacity Target

```python
target_weekly_cap = 75  # Change to your team's available hours per week
```

### Locking Specific Rules to a Review Type

```python
locked_rules = {
    'LTVHigherThresholdBreached': 'Deep',
    # Add more rules as needed
}
```

### Adjusting Time Windows

Modify the date range in the SQL query:

```sql
-- Change from 6 months to custom period
WHERE TIME_CREATED >= DATEADD(month, -6, CURRENT_DATE())
```

### Adding New Rule Patterns

Add rule names by updating the `CASE WHEN` statements in the SQL query:

```sql
WHEN UPPER(metadata) LIKE UPPER('%YourNewRuleName%') THEN 'YourNewRuleName'
```

### Modifying Priority Score Weights

```python
priority_score = (0.6 * normalized_loss) + (0.25 * precision_rate) + (0.15 * normalized_volume)
```

### Updating Operational Inputs

These lists must align with the `Rule_Name` order in `current_state`:

```python
Avg_Cases_Per_Month = [...]          # Monthly case volumes per rule
Avg_Handling_Time_Minutes = [...]    # Average handling time per case per rule
'rule_precision_L3M': [...]          # Rule-level precision from dashboard
'per_case_Precision_%': [...]        # Per-case precision
```

## Data Privacy and Security

- **Credential Management**: Use environment variables or secure credential stores instead of hardcoding
- **SSO Authentication**: Okta EXTERNALBROWSER authentication required
- **Output Sanitization**: Review outputs for sensitive information before sharing externally
- **Access Control**: Ensure appropriate Snowflake role permissions are configured
- **Data Retention**: Follow your organization's data retention policies when storing analysis results

## Contributing

Contributions are welcome! If you'd like to improve the analysis or add new features:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add new feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

## Use Cases

- **Resource Planning**: Determine optimal staffing levels for different review types
- **Rule Optimization**: Identify underperforming rules for refinement or deprecation
- **Training Priorities**: Focus analyst training on high-impact rule patterns
- **Policy Development**: Data-driven evidence for review policy changes
- **Quarterly Reviews**: Track rule effectiveness trends over time

## Limitations

- Analysis requires 6 months of historical data for statistical significance
- Precision rates and average case volumes/handling times need to be manually updated when changes occur
- The optimization cannot propose a review type higher than the current type (only downgrades or same)

## Author

**Prisca Adenike Adeoti**

Receive Risk Card Fraud Prevention Analyst (PAYFAC)

March 2026

---

**Questions or Issues?** Open an issue in the repository or contact the author for support.
