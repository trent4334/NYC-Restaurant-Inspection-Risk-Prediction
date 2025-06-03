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

### 1. Data Cleaning
- Selected relevant columns
- Removed duplicates and missing values
- Aggregated data to one row per inspection (maximum score per inspection date)

### 2. Feature Engineering
- Extracted:
  - Inspection month and weekday
  - Previous inspection history (count of low/medium/high scores, prior closings)
  - Borough and cuisine category

### 3. Modeling
- **Logistic Regression:** Baseline model with metadata only
- **Random Forest:** Extended model including past inspection outcomes

### 4. Evaluation
- Compared models using AUC and top-k precision
- Visualized performance across different thresholds

---

## 📊 Results

| Metric              | Logistic Regression | Random Forest |
|---------------------|---------------------|---------------|
| **AUC**             | 0.635               | 0.733         |
| **Top-k Precision** | Lower               | Higher        |

- **Random Forest** significantly outperformed logistic regression
- Models with prior inspection history proved more effective at identifying high-risk restaurants

> Precision-at-k plots confirm that Random Forest better ranks the riskiest establishments near the top of the list.

---

## 📁 Files

- `assignment6.R`: Core R functions for processing, modeling, and evaluation
- `assignment6_workflow.Rmd`: RMarkdown file with the full analysis pipeline
- `Workflow.pdf`: Final rendered report

---

## 🧰 Tools Used

- R (`tidyverse`, `ranger`, `ROCR`)
- NYC Open Data API
- RMarkdown for documentation and reporting

---

## 🚀 Future Extensions

- Add hyperparameter tuning for model optimization
- Explore gradient boosting or ensemble stacking
- Integrate recent years (2020–2023) to update risk scores

---

## ⚠️ Note

Original file names were retained for compatibility with coursework grading requirements. However, the project reflects practical modeling techniques used in applied data science and public health analytics.
