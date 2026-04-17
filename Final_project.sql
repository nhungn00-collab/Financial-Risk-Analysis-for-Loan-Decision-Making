SELECT TOP 5 *
FROM Financial_risk.dbo.Financial_risk_assessment;

--Check Null
SELECT
    COUNT(Age) AS Age_NotNull,
    COUNT(Income) AS Income_NotNull,
    COUNT(Credit_Score) AS Credit_Score_NotNull,
    COUNT(Loan_Amount) AS Loan_Amount_NotNull,
    COUNT(Assets_Value) AS Assets_Value_NotNull,
    COUNT(Number_of_Dependents) AS Number_of_Dependents_NotNull,
    COUNT(Previous_Defaults) AS Previous_Defaults_NotNull,

    COUNT(*) - COUNT(Age) AS Age_Null,
    COUNT(*) - COUNT(Income) AS Income_Null,
    COUNT(*) - COUNT(Credit_Score) AS Credit_Score_Null,
    COUNT(*) - COUNT(Loan_Amount) AS Loan_Amount_Null,
    COUNT(*) - COUNT(Assets_Value) AS Assets_Value_Null,
    COUNT(*) - COUNT(Number_of_Dependents) AS Number_of_Dependents_Null,
    COUNT(*) - COUNT(Previous_Defaults) AS Previous_Defaults_Null

FROM Financial_risk.dbo.Financial_risk_assessment;

--Xử lý Null -> Median 
WITH MedianValues AS (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Income) OVER () AS median_income,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Credit_Score) OVER () AS median_credit,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Loan_Amount) OVER () AS median_loan,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Assets_Value) OVER () AS median_assets
    FROM Financial_risk.dbo.Financial_risk_assessment
)

UPDATE t
SET 
    Income = COALESCE(Income, m.median_income),
    Credit_Score = COALESCE(Credit_Score, m.median_credit),
    Loan_Amount = COALESCE(Loan_Amount, m.median_loan),
    Assets_Value = COALESCE(Assets_Value, m.median_assets)
FROM Financial_risk.dbo.Financial_risk_assessment t
CROSS JOIN (SELECT DISTINCT * FROM MedianValues) m;

--Check lại sau khi xử lý Null
SELECT *
FROM Financial_risk.dbo.Financial_risk_assessment
WHERE Income IS NULL
   OR Credit_Score IS NULL
   OR Loan_Amount IS NULL
   OR Assets_Value IS NULL;

-- Check dulicate 
SELECT 
    Age, Gender, Education_Level, Marital_Status,
    Income, Credit_Score, Loan_Amount, Loan_Purpose,
    Employment_Status, Years_at_Current_Job,
    Payment_History, Debt_to_Income_Ratio,
    Assets_Value, Number_of_Dependents,
    City, Previous_Defaults,
    COUNT(*) AS cnt
FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY 
    Age, Gender, Education_Level, Marital_Status,
    Income, Credit_Score, Loan_Amount, Loan_Purpose,
    Employment_Status, Years_at_Current_Job,
    Payment_History, Debt_to_Income_Ratio,
    Assets_Value, Number_of_Dependents,
    City, Previous_Defaults
HAVING COUNT(*) > 1;

-- avg credit score vs Risk
SELECT 
    Risk_Rating,
    AVG(Credit_Score) AS avg_credit_score,
    COUNT(*) AS total_customers
FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY Risk_Rating
ORDER BY avg_credit_score;
--> CS thấp -> Risk thấp, nhưng ko có sự khác biệt giữa high và medium (avg=699)
=> ko hợp lý, vì high risk -> score thấp

--Income vs Risk
SELECT 
    Risk_Rating,
    AVG(Income) AS avg_income,
    COUNT(*) AS total_customers
FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY Risk_Rating
ORDER BY avg_income;
--> High risk khi income thấp, nhưng lại ko phản ánh được low risk khi income cao nhất

--DTI vs Risk
SELECT 
    Risk_Rating,
    AVG(Debt_to_Income_Ratio) AS avg_dti,
    COUNT(*) AS total_customers
FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY Risk_Rating
ORDER BY avg_dti DESC;
--> DTI càng cao → Risk càng cao => Khách hàng có tỷ lệ nợ trên thu nhập cao hơn sẽ thuộc nhóm rủi ro cao

--Loan purpose vs Risk
SELECT 
    Loan_Purpose,
    Risk_Rating,
    COUNT(*) AS total_customers
FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY Loan_Purpose, Risk_Rating
ORDER BY Loan_Purpose;
--> Mục đích vay vốn đóng vai trò quan trọng trong việc đánh giá rủi ro, trong đó các khoản vay kinh doanh có tỷ lệ khách hàng rủi ro cao cao hơn
--- check tỷ lệ của từng Loan purpose
SELECT 
    Loan_Purpose,
    Risk_Rating,
    COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY Loan_Purpose) AS ratio
FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY Loan_Purpose, Risk_Rating;

--Employment Status vs Risk
SELECT 
    Employment_Status,
    Risk_Rating,
    COUNT(*) AS total
FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY Employment_Status, Risk_Rating
Order by Employment_Status DESC;
--> Unemployed → High Risk cao Employed → Low Risk nhiều hơn => Những người thất nghiệp có tỷ lệ thuộc nhóm rủi ro cao hơn đáng kể so với khách hàng đang có việc làm

--Payment History vs Risk
SELECT 
    Payment_History,
    Risk_Rating,
    COUNT(*) AS total
FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY Payment_History, Risk_Rating
ORDER BY Payment_History;
-->Payment History KHÔNG ảnh hưởng đến Risk Rating

--check tỷ lệ risk
SELECT 
    Risk_Rating,
    COUNT(*) AS total_customers,
    COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS ratio
FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY Risk_Rating
ORDER BY total_customers DESC;
--> low risk 60%, medium 30%, high 10%

--Unemployed + Poor Payment → có High Risk không?
SELECT 
    Employment_Status,
    Payment_History,
    Risk_Rating,
    COUNT(*) AS total
FROM Financial_risk.dbo.Financial_risk_assessment
WHERE Employment_Status = 'Unemployed'
  AND Payment_History = 'Poor'
GROUP BY Employment_Status, Payment_History, Risk_Rating
ORDER BY total DESC;
--> Điều đáng ngạc nhiên là, những khách hàng thất nghiệp và có lịch sử thanh toán kém lại chủ yếu được xếp vào nhóm rủi ro thấp. Điều này trái ngược với hành vi tài chính thông thường và cho thấy mô hình phân loại rủi ro có thể chưa tích hợp hiệu quả các chỉ số rủi ro chính.

--Debt-to-Income bao nhiêu thì High Risk?
SELECT 
    CASE 
        WHEN Debt_to_Income_Ratio < 0.2 THEN 'Low Debt'
        WHEN Debt_to_Income_Ratio BETWEEN 0.2 AND 0.4 THEN 'Medium Debt'
        ELSE 'High Debt'
    END AS debt_group,

    Risk_Rating,
    COUNT(*) AS total

FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY 
    CASE 
        WHEN Debt_to_Income_Ratio < 0.2 THEN 'Low Debt'
        WHEN Debt_to_Income_Ratio BETWEEN 0.2 AND 0.4 THEN 'Medium Debt'
        ELSE 'High Debt'
    END,
    Risk_Rating
ORDER BY debt_group;
---tính theo tỷ lệ
SELECT 
    CASE 
        WHEN Debt_to_Income_Ratio < 0.2 THEN 'Low Debt'
        WHEN Debt_to_Income_Ratio BETWEEN 0.2 AND 0.4 THEN 'Medium Debt'
        ELSE 'High Debt'
    END AS debt_group,

    AVG(CASE WHEN Risk_Rating = 'High' THEN 1.0 ELSE 0 END) AS high_risk_rate

FROM Financial_risk.dbo.Financial_risk_assessment
GROUP BY 
    CASE 
        WHEN Debt_to_Income_Ratio < 0.2 THEN 'Low Debt'
        WHEN Debt_to_Income_Ratio BETWEEN 0.2 AND 0.4 THEN 'Medium Debt'
        ELSE 'High Debt'
    END
ORDER BY high_risk_rate DESC;
--> Tỷ lệ nợ trên thu nhập không cho thấy mối quan hệ có ý nghĩa nào với xếp hạng rủi ro, vì tỷ lệ khách hàng rủi ro cao vẫn gần như giống nhau ở cả nhóm nợ thấp và nhóm nợ cao.
-->High Debt, High Risk: ≈ 10.2%, Medium: ~30%, Low: ~59.7%. Low Debt: High Risk ≈ 10.4%, Medium: ~30%, Low: ~59.2%
