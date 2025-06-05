# NYC Restaurant Inspection Risk Prediction

This project uses open data from the New York City Department of Health and Mental Hygiene to build predictive models that help prioritize restaurant inspections. Faced with limited staff resources, the goal is to identify restaurants likely to receive a high inspection score (indicating worse violations) so inspectors can be deployed more effectively.

> 📌 Originally developed as part of a NYU data science course. Adapted for portfolio presentation.

---

## 📦 Dataset

- **Source:** [NYC DOHMH Restaurant Inspection Results](https://data.cityofnewyork.us/Health/DOHMH-New-York-City-Restaurant-Inspection-Results/43nn-pn8j)
- **Rows:** Each row represents a violation from a restaurant inspection.
- **Timeframe:** 2017–2019

---

## ⚙️ Workflow

## 🧹 Step 1: Clean and Prepare the Data

We filtered and cleaned the raw NYC inspection data by:

- Keeping only relevant columns (e.g., score, violation code, grade, date)
- Standardizing string values in `action` and `inspection_type`
- Dropping invalid records
- Aggregating scores per inspection date by taking the max

📌 **Insight**: Cleaning this data is critical because each inspection may result in multiple rows (violations). Modeling must happen at the inspection level, not the row level.

---

## 🧪 Step 2: Define Outcome and Filter to Initial Inspections

We isolated initial cycle inspections between 2017 and 2019 and flagged those with scores ≥28 as high-risk (`outcome = TRUE`).

📌 **Insight**: Filtering to only first inspections eliminates noise from follow-ups and gives a cleaner target variable for modeling.

---

## ⚙️ Step 3: Create Predictive Features

We created restaurant-level features such as:

- Past counts of low/medium/high scores
- Count of prior closures
- Temporal features: `month`, `weekday`

📌 **Insight**: These historical features greatly improved performance, especially for the Random Forest model. It shows how compliance patterns over time are strong predictors.

---

## 🤖 Step 4: Train Predictive Models

Two models were trained and tested:

- **Logistic Regression**: Basic categorical/time-based features
- **Random Forest**: Full feature set with historical stats

Test set: inspections from 2019  
Performance metrics: AUC, Precision-at-k

📌 **Insight**: Although logistic regression was simpler, it consistently underperformed Random Forest in identifying high-risk restaurants.

---

## 📊 Step 5: Evaluate Models with Precision-at-k

The plot below shows how precise each model is in identifying true positives among the top-k predictions.

<img width="926" alt="Screenshot 2025-06-05 at 17 22 13" src="https://github.com/user-attachments/assets/65af7176-4a65-42d3-8144-22ab3774e63f" />

📌 **Insight**:
- Random Forest has substantially higher precision across all values of k.
- At k = 100, Random Forest had over 55% precision, while Logistic Regression struggled to surpass 40%.
- This matters because top-k prioritization mirrors real-world inspection constraints.

---

## 🧠 Reflections

### Model Preference

- **Random Forest** is preferable for this task due to better AUC and precision-at-k.
- Logistic regression could be useful for interpretability but sacrifices performance.

### Bias & Fairness

- **Subjective flags** (like `critical`) may carry implicit bias from inspectors.
- Model results should be audited regularly to detect and mitigate institutional bias.

### Practical Usage

- Prioritizing by risk score is effective but could overlook **rising risks** in “clean” restaurants.
- Combining prediction with **complaints data** or **Yelp reviews** could improve targeting.

---

## 📌 Future Directions

- Add **geospatial clustering** to target hotspot zones
- Implement **online dashboards** for inspector teams
- Integrate with real-time feedback (complaints, social data)

---
