# Rule Loss Estimation Analysis

A Fraud Prevention rules review type analysis tool for optimizing CRM capacity for Payfac. This notebook analyzes historical fraud data to prioritize merchant review rules based on loss, precision, and volume metrics.

![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![Jupyter](https://img.shields.io/badge/jupyter-notebook-orange.svg)

## Overview

This analysis tool helps fraud prevention and CRM teams make data-driven decisions about resource allocation in Acquiring merchant review processes. By analyzing 6 months of historical fraud data, it identifies which merchant review rules generate the highest losses, evaluates their precision, and recommends optimal review types (Deep/Standard/Light) for each rule pattern.

**Target Audience**: Fraud prevention, Acquiring risk operations teams (CRM).

## Features

- **Comprehensive 6-Month Fraud Loss Analysis** across 17+ merchant review rules
- **Automated Loss Calculation** for both NOF (Notofication of Fraud) and chargeback losses
- **Rule Precision Rate Analysis** to identify most effective review triggers
- **Priority Scoring System** with weighted metrics (50% loss, 30% precision, 20% volume)
- **Review Type Optimization** with recommendations for Deep/Standard/Light review assignments
- **Formatted Outputs** with summary statistics and actionable insights
- **Deduplication Logic** to ensure accurate per-merchant, per-rule analysis

## Prerequisites

### Technical Requirements

- **Python 3.12+**
- **Jupyter Notebook** or JupyterLab
- **Required Python Packages**:
  - `snowflake-snowpark-python` - Snowflake data warehouse connectivity
  - `pandas` - Data manipulation and analysis
  - `numpy` - Numerical computing

### Access Requirements

- **Snowflake Account Access** (Wise analytics warehouse)
- **Okta SSO Authentication** configured
- **Database Permissions** for:
  - `ANALYTICS_DB.DDCASE.DD_CASE` - Case management data
  - `ANALYTICS_DB.RPT_PRODUCT.PAY_WITH_CARD_MERCHANTS` - Merchant profiles
  - `ANALYTICS_DB.RPT_PRODUCT.PAY_WITH_CARD_PAYMENTS` - Payment transactions

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
   - Loss estimation
   - Summary statistics
   - Rule prioritization rankings pased on the final score
   - Current state analysis (then make new recomendations)

## Outputs

### Loss Analysis Table

For each merchant review rule, the analysis provides:
- **Unique Merchants**: Count of distinct merchants flagged by the rule
- **Total Payments**: Number of payment transactions processed
- **NOF Amount**: Confirmed fraud losses (£)
- **Chargeback Amount**: Chargeback (£)
- **Total Fraud**: Combined NOF + chargeback losses (£)
- **Precision %**: Per case preciison,  not based on per profile. If a rule hits 3 times on 1 profile and the 3rd time we offboard precision is 33%	
- **Avg Fraud per Problematic Merchant**: Expected loss per risky merchant (not toal merchant flagged by the rule). This will give an idea of if we do not review a merchant by this rule and they turn out to be bad, how much we might lose on average

### Summary Statistics

Aggregate metrics including:
- Total fraud across all rules
- Monthly average fraud
- Total unique merchants analyzed
- Total payments processed
- Average precision rate

### Priority Scoring

Rules ranked by composite priority score:
- **50% Weight**: Total fraud loss
- **30% Weight**: Precision rate
- **20% Weight**: Transaction volume

### Review Type Recommendations

Suggested resource allocation for each rule:
- **Deep Review** (~48 min): High-risk rules requiring comprehensive investigation
- **Standard Review** (~35 min): Moderate-risk rules with balanced investigation needs
- **Light Review** (~12 min): Lower-risk patterns requiring quick investigation

## Key Metrics Explained

| Metric | Definition | Business Impact |
|--------|------------|----------------|
| **NOF (Notification of Fraud)** | Confirmed fraud transactions  | PSP impacts|
| **Chargeback Amount** | Customer dispute losses | Reputational and financial impact |
| **Total Fraud** | Combined NOF + chargeback losses | Overall rule effectiveness measure |
| **Precision %** | Reviews that identify actual fraud / Total reviews | Resource efficiency indicator |
| **Priority Score** | Weighted composite metric | Resource allocation guide |
| **Avg Fraud per Problematic Merchant** | Expected loss if risky merchant isn't caught | Risk prioritization metric |

## Example Results

Based on actual analysis of 6 months of fraud data:

### Top Loss Rules
1. **AttemptedAmountExceedsTransferAmount**: £45,944 total fraud
2. **PaymentForRequestRecentlyPublished**: £44,306 total fraud
3. **SuspiciousPaymentActivity**: £31,687 total fraud
4. **RapidMerchantOnboarding**: £28,415 total fraud

### Summary Metrics
- **Total Fraud Across All Rules**: £207,351
- **Monthly Average Fraud**: £34,559
- **Unique Merchants Analyzed**: 2,543
- **Total Payments Processed**: 7,623
- **Average Precision Rate**: 23.4%


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

### Review Type Classification

The analysis categorizes rules into three review tiers based on priority scores:

- **Deep Review (~48 minutes)**
  - Comprehensive investigation for high-risk rules
  - Includes detailed merchant background checks, transaction pattern analysis, and external data verification

- **Standard Review (~35 minutes)**
  - Balanced investigation for moderate risk
  - Standard review procedures with focused checks on key risk indicators

- **Light Review (~12 minutes)**
  - Quick review for lower-risk patterns
  - Automated checks with manual oversight on specific triggers

### Priority Score Calculation

```python
priority_score = (0.5 * normalized_loss) + (0.3 * precision_rate) + (0.2 * normalized_volume)
```

Where:
- `normalized_loss` = (rule_loss / max_rule_loss)
- `precision_rate` = (fraud_cases / total_cases)
- `normalized_volume` = (rule_volume / max_rule_volume)

## Customization

### Adjusting Time Windows

Modify the date range in the SQL query:

```python
# Change from 6 months to custom period
date_threshold = (datetime.now() - timedelta(days=180))  # Change 180 to desired days
```

### Adding New Rule Patterns

Add rule names to the analysis by updating the rule extraction logic:

```python
# Add new rule patterns to the CASE WHEN statements in the SQL query
WHEN rule_content LIKE '%YourNewRule%' THEN 'YourNewRule'
```

### Modifying Priority Score Weights

Adjust weights based on organization's priorities:

```python
priority_score = (0.6 * normalized_loss) + (0.25 * precision_rate) + (0.15 * normalized_volume)
# Increase loss weight, decrease volume weight
```

### Changing Review Time Constants

Update review time allocations:

```python
DEEP_REVIEW_TIME = 60  # minutes
STANDARD_REVIEW_TIME = 40  # minutes
LIGHT_REVIEW_TIME = 15  # minutes
```

Update per case precision for rules:

```python
'per_case_Precision_%'= ['update/add new precisions here delimited by comma for the rules as listed in Rule_Name']
    
```

Update per case precision for rules:

```python
'Avg_Cases_Per_Month'= ['update/add new average case per month delimited by comma for the rules as listed in Rule_Name']
    
```
Update per case precision for rules:

```python
Avg_Handling_Time_Minutes= ['update/add new average handing time values delimited by comma for the rules as listed in Rule_Name']

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

This analysis supports several operational workflows:

- **Resource Planning**: Determine optimal staffing levels for different review types
- **Rule Optimization**: Identify underperforming rules for refinement or deprecation
- **Training Priorities**: Focus analyst training on high-impact rule patterns
- **Policy Development**: Data-driven evidence for review policy changes
- **Quarterly Reviews**: Track rule effectiveness trends over time

## Limitations

- Analysis requires 6 months of historical data for statistical significance
- Precision rates need to be manually added when changes occur


## Author

**Prisca Adenike Adeoti**

Receive Risk Card Fraud Prevention Analyst (PAYFAC)

March 2026


---

**Questions or Issues?** Open an issue in the repository or contact the author for support.
