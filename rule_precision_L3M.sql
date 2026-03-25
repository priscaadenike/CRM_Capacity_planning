WITH payfac_dd_cases AS (
  WITH case_review_times AS (
    SELECT
      CASE_STATE_CHANGE.CASE_ID,
      DD_CASE.REFERENCE_ID AS PROFILE_ID,
      DD_CASE.REFERENCE_TYPE,
      DD_CASE.TIME_CREATED,
      DD_CASE.LAST_UPDATED,
      DD_CASE.CASE_TYPE,
      DD_CASE.CREATOR,
      DD_CASE.STATE,
      DD_CASE.METADATA AS rule_triggered,
      MIN(CASE WHEN EVENT = 'CASE_CREATION' THEN CASE_STATE_CHANGE.TIME_CREATED END) AS case_created_time,
      MIN(CASE WHEN EVENT = 'ASSIGN'        THEN CASE_STATE_CHANGE.TIME_CREATED END) AS case_assigned_time,
      MIN(CASE WHEN EVENT = 'CLOSE'         THEN CASE_STATE_CHANGE.TIME_CREATED END) AS case_closed_time,
      MIN(CASE WHEN EVENT = 'ASSIGN'        THEN CASE_STATE_CHANGE.ACTOR        END) AS assigned_actor
    FROM DDCASE.CASE_STATE_CHANGE CASE_STATE_CHANGE
    LEFT JOIN DDCASE.DD_CASE
      ON CASE_STATE_CHANGE.CASE_ID = DD_CASE.ID
    WHERE DD_CASE.CASE_TYPE IN ('ACQUIRING_MERCHANT_REVIEW', 'PAYFAC_DUE_DILIGENCE')
    GROUP BY 1,2,3,4,5,6,7,8,9
  )
  SELECT
    case_review_times.*,
    DATEDIFF('minute', case_created_time, case_assigned_time) AS minutes_created_to_assignment,
    DATEDIFF('hour',   case_created_time, case_assigned_time) AS hours_created_to_assigned,
    DATEDIFF('minute', case_assigned_time, case_closed_time)   AS minutes_assigned_to_reviewed,
    DATEDIFF('hour',   case_created_time, case_closed_time)    AS hours_created_to_reviewed
  FROM case_review_times
)
SELECT
  (CASE
    WHEN (UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_PaymentForRequestRecentlyPublished_REVIEW_MERCHANT')
       OR UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_PaymentForRequestRecentlyPublished_DECLINE_and_PAUSE_MERCHANT'))
      THEN 'Payment for Request'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_UniqueCardsRefusedLast24HoursThresholdBreached_PauseMerchant')
      THEN 'Unique Cards Single'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_UniqueCardsRefusedLast24HoursThresholdBreached_Reusable_PauseMerchant')
      THEN 'Unique Cards Reusable'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_UniqueCardsRefusedLast24HoursThresholdBreached_Wisetag_PauseMerchant')
      THEN 'Unique Cards Wisetag'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_emailAgeScoreAboveThreshold_ReviewMerchant')
      THEN 'Emailage Score'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_HighRiskIssuerRefusalReason_ReviewMerchant')
      THEN 'Refusal Reason'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_PAYFAC_POST_AUTH_PAYFAC_SUB_MERCHANTAbuserFlag_AlertSlack')
      THEN 'AbuserFlag'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_AverageDailyPayFacTransactionExceedsAverageDailyTransfer_PauseMerchant')
      THEN 'PF Transaction Exceeds Average Daily Transfer (Velocity)'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_AttemptedAmountExceedsTransferAmount_PauseMerchant')
      THEN 'PF Attempt Exceeds Transfer Amount (Velocity)'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_Bin6AttemptedVolumeSpike_ReviewMerchant')
      THEN 'BIN Spike'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_ProtonmailEmailDomain_PauseMerchant')
      THEN 'Protonmail'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_WithdrawalRule_PauseMerchant')
      THEN 'Withdrawal Rule'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_LTVHigherThresholdBreached_PauseMerchant')
      THEN 'Higher LTV rule'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_LTVLowerThresholdBreached_ReviewMerchant')
      THEN 'Lower LTV rule'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_PayerDisputeThreshold_ReviewMerchant')
      THEN 'Payer Dispute Threshold'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_IssuerIcardADPattern_DeclineAndOffboard')
      THEN 'Issuer IcardAD rule'
    WHEN UPPER(payfac_dd_cases.rule_triggered) = UPPER('Rule fired - o_IssuerAndMerchantConcentration_ReviewMerchant')
      THEN 'Issuer and Merchant Concentration'
    ELSE 'Transaction amount'
  END) AS rule_group,

  -- 1) Profiles flagged by risk rules in last 3 months (based on assignment time)
  COUNT(DISTINCT CASE
    WHEN UPPER(payfac_dd_cases.CASE_TYPE) = UPPER('ACQUIRING_MERCHANT_REVIEW')
     AND payfac_dd_cases.case_assigned_time >= DATEADD('month', -3, CURRENT_DATE())
     AND payfac_dd_cases.case_assigned_time <  CURRENT_DATE()
    THEN payfac_dd_cases.PROFILE_ID
    ELSE NULL
  END) AS profiles_flagged_by_risk_rules,

  -- 2) Profiles flagged and offboarded in last 3 months (based on assignment time)
  COUNT(DISTINCT CASE
    WHEN UPPER(payfac_dd_cases.CASE_TYPE) = UPPER('ACQUIRING_MERCHANT_REVIEW')
     AND payfac_merchants.date_offboarded IS NOT NULL
     AND (UPPER(payfac_merchants.offboarding_reason) <> UPPER('hidden_account')
          OR payfac_merchants.offboarding_reason IS NULL)
     AND UPPER(payfac_dd_cases.STATE) = UPPER('CLOSED')
     AND payfac_dd_cases.case_assigned_time >= DATEADD('month', -3, CURRENT_DATE())
     AND payfac_dd_cases.case_assigned_time <  CURRENT_DATE()
    THEN payfac_dd_cases.PROFILE_ID
    ELSE NULL
  END) AS profiles_flagged_and_offboarded,

  -- 3) Profiles flagged and deactivated by fraud in last 3 months (based on case creation)
  COUNT(DISTINCT CASE
    WHEN payfac_dd_cases.TIME_CREATED >= DATEADD('month', -3, CURRENT_DATE())
     AND payfac_dd_cases.TIME_CREATED <  CURRENT_DATE()
     AND UPPER(payfac_dd_cases.CASE_TYPE) = UPPER('ACQUIRING_MERCHANT_REVIEW')
     AND payfac_merchants.DEACTIVATION_REASON IS NOT NULL
    THEN payfac_merchants.PROFILE_ID
    ELSE NULL
  END) AS profiles_flagged_by_rule_and_deactivated_by_fraud,

  -- 4) Precision: offboarded / flagged
  ROUND(CASE
    WHEN COUNT(DISTINCT CASE
           WHEN UPPER(payfac_dd_cases.CASE_TYPE) = UPPER('ACQUIRING_MERCHANT_REVIEW')
            AND payfac_dd_cases.case_assigned_time >= DATEADD('month', -3, CURRENT_DATE())
            AND payfac_dd_cases.case_assigned_time <  CURRENT_DATE()
           THEN payfac_dd_cases.PROFILE_ID END) = 0
      THEN NULL
    ELSE
      COUNT(DISTINCT CASE
        WHEN UPPER(payfac_dd_cases.CASE_TYPE) = UPPER('ACQUIRING_MERCHANT_REVIEW')
         AND payfac_merchants.date_offboarded IS NOT NULL
         AND (UPPER(payfac_merchants.offboarding_reason) <> UPPER('hidden_account')
              OR payfac_merchants.offboarding_reason IS NULL)
         AND UPPER(payfac_dd_cases.STATE) = UPPER('CLOSED')
         AND payfac_dd_cases.case_assigned_time >= DATEADD('month', -3, CURRENT_DATE())
         AND payfac_dd_cases.case_assigned_time <  CURRENT_DATE()
        THEN payfac_dd_cases.PROFILE_ID END
      )
      /
      COUNT(DISTINCT CASE
        WHEN UPPER(payfac_dd_cases.CASE_TYPE) = UPPER('ACQUIRING_MERCHANT_REVIEW')
         AND payfac_dd_cases.case_assigned_time >= DATEADD('month', -3, CURRENT_DATE())
         AND payfac_dd_cases.case_assigned_time <  CURRENT_DATE()
        THEN payfac_dd_cases.PROFILE_ID END
      )
  END, 4) * 100 AS precision_L3M

FROM RPT_PRODUCT.request_money_main_dataset AS request_money_full_dataset
FULL OUTER JOIN RPT_PRODUCT.PAY_WITH_CARD_PAYMENTS AS pay_with_card
  ON request_money_full_dataset.PAYMENT_REQUEST_ID = pay_with_card.PAYMENT_REQUEST_ID
 AND request_money_full_dataset.PSP_REFERENCE     = pay_with_card.PSP_REFERENCE
FULL OUTER JOIN RPT_PRODUCT.pay_with_card_merchants AS payfac_merchants
  ON payfac_merchants.PROFILE_ID = pay_with_card.profile_id
LEFT JOIN payfac_dd_cases
  ON payfac_dd_cases.PROFILE_ID = payfac_merchants.PROFILE_ID

WHERE
  (
    UPPER(payfac_merchants.PROFILE_ID) <> UPPER('64074335')
    AND UPPER(payfac_merchants.PROFILE_ID) <> UPPER('50973537')
    AND UPPER(payfac_merchants.PROFILE_ID) <> UPPER('48384863')
    AND UPPER(payfac_merchants.PROFILE_ID) <> UPPER('12905779')
    OR payfac_merchants.PROFILE_ID IS NULL
  )
  AND (
    UPPER(payfac_merchants.profile_onboarding_status) = UPPER('OFFBOARDED')
    OR UPPER(payfac_merchants.profile_onboarding_status) = UPPER('ONBOARDED')
  )

GROUP BY 1
ORDER BY 1
FETCH NEXT 500 ROWS ONLY;