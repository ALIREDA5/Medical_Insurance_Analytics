# Databricks notebook source
# MAGIC %md
# MAGIC # Patient

# COMMAND ----------

# MAGIC %md
# MAGIC ## Initialization

# COMMAND ----------

import sys

sys.path.append('/Workspace/Users/mommensabry@gmail.com/Medical_Insurance_Analytics/lakehouse/libs')
from pyspark.sql.functions import (
    col,
    trim,
    lower,
    upper,
    length,
    substring,
    count,
    min,
    max,
    when,
    lit,
    coalesce,
    row_number,
    current_timestamp
)

from pyspark.sql.window import Window
from silver_utils import *

# COMMAND ----------

# MAGIC %md
# MAGIC ## Read Bronze table

# COMMAND ----------

df = spark.table("medical_insurance.default.patient")

display(df)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Profiling

# COMMAND ----------

df.printSchema()

# COMMAND ----------

display(df.describe())

# COMMAND ----------

from pyspark.sql.functions import col, count, min, max

results = []

for column in df.columns:
    
    # Count unique values
    unique_count = df.select(column).distinct().count()
    
    # Most frequent value and its count
    top_value = (
        df.groupBy(column)
        .count()
        .orderBy(col("count").desc())
        .first()
    )
    
    # Min and max values
    min_value = df.select(min(col(column))).first()[0]
    max_value = df.select(max(col(column))).first()[0]

    # Append results
    results.append({
        "column": column,
        "unique_values": unique_count,
        "most_frequent_value": top_value[0],
        "appearance_count": top_value[1],
        "min_value": min_value,
        "max_value": max_value
    })

# Create final DataFrame with ordered columns
results = spark.createDataFrame(results).select(
    "column",
    "unique_values",
    "most_frequent_value",
    "appearance_count",
    "min_value",
    "max_value"
)

# Display nicely in Databricks
display(results)

# COMMAND ----------

display(
    df.filter(col("phone") == col("emergency_contact"))
)

# COMMAND ----------

#from pyspark.sql.functions import length, col

df.select(
    "phone",
    length(col("phone")).alias("phone_length")
).show()

# COMMAND ----------

display(
    df.filter(length(col("phone")) != 10)
)

# COMMAND ----------

display(
    df.filter(
        ~substring(col("phone"), 1, 2).isin("11", "10", "15", "12")
    )
)

# COMMAND ----------

dup_phones = df.groupBy("phone") \
    .count() \
    .filter(col("count") > 1) \
    .select("phone")

display(df.join(dup_phones, "phone", "inner"))

# COMMAND ----------

dup_phones = df.groupBy("gender") \
    .count() \
    .filter(col("count") > 1) \
    .show()

# COMMAND ----------

columns_to_check = ["gender", "city","governorate", "blood_type"]

results = []

for c in columns_to_check:
    
    dup = df.groupBy(c) \
        .count() \
        .filter(col("count") > 1) \
        .withColumn("column", lit(c)) \
        .select("column", col(c).alias("value"), "count")
    
    results.append(dup)

final_df = results[0]
for r in results[1:]:
    final_df = final_df.union(r)

display(final_df)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Cleaning

# COMMAND ----------

# MAGIC %md
# MAGIC 1- nullable = True
# MAGIC 2- ID = Decimal
# MAGIC 3- Phone and emerhency_contact has null
# MAGIC 4- Full Name
# MAGIC 5- Check phone and emergency contanct are not the same
# MAGIC 6- Age
# MAGIC 7- Handling error not exist like (duplicated id, duplicated record, null values,Male & Female)

# COMMAND ----------

# MAGIC %md
# MAGIC **Invalid rows count** = number of records that fail your data quality rules.
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ## Simple meaning
# MAGIC
# MAGIC Rows that are **wrong or unusable** for your system.
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ## Example (Patient table)
# MAGIC
# MAGIC A row is invalid if:
# MAGIC
# MAGIC ### 1. Missing required data
# MAGIC
# MAGIC * `patient_id = NULL`
# MAGIC * `national_id = NULL`
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ### 2. Wrong logic
# MAGIC
# MAGIC * `birth_date > today` (future birth date)
# MAGIC * `age < 0`
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ### 3. Business rule violation
# MAGIC
# MAGIC * `gender not in (Male, Female)`
# MAGIC * `blood_type invalid`
# MAGIC * `phone = emergency_contact`
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ### 4. Format issues
# MAGIC
# MAGIC * phone too short/long
# MAGIC * national_id not numeric (if required)
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ## So:
# MAGIC
# MAGIC ```text id="v1"
# MAGIC invalid_rows_count = number of rows failing ANY rule
# MAGIC ```
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ## Example
# MAGIC
# MAGIC If you have 1000 patients:
# MAGIC
# MAGIC * 950 valid
# MAGIC * 50 invalid
# MAGIC
# MAGIC Then:
# MAGIC
# MAGIC ```text id="v2"
# MAGIC invalid_rows_count = 50
# MAGIC ```
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ## Why it matters
# MAGIC
# MAGIC Used for:
# MAGIC
# MAGIC * data quality KPI
# MAGIC * auditing
# MAGIC * fixing source system issues
# MAGIC * deciding reject vs clean pipeline
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC If you want, I can help you design a **formal data quality rules table for your whole patient dataset**.
# MAGIC

# COMMAND ----------

# MAGIC %md
# MAGIC ### Silver Transformation

# COMMAND ----------

# Rename column
df = rename_columns(df, {"phone": "patient_phone"})

# Create patient_name
df = df.withColumn(
    "patient_name",
    concat_ws(" ", col("first_name"), col("last_name"))
)

# Drop old columns
df = df.drop("first_name", "last_name")

# COMMAND ----------

from pyspark.sql.functions import year, current_date, when

df = (
    df.transform(lambda d: remove_duplicates(d, ["patient_id"]))
      .transform(trim_all_string_columns)
      .transform(replace_null_strings)
)

# Calculate age
df = df.withColumn("patient_age", year(current_date()) - year(col("birth_date")))

# concat 0 to phone numbers with length less than 10
df = df.withColumn("patient_phone", concat(lit("0"), col("patient_phone")))
df = format_egypt_phone_numbers(df, ["patient_phone"])

df = df.withColumn("emergency_contact", concat(lit("0"), col("emergency_contact")))
df = format_egypt_phone_numbers(df, ["emergency_contact"])

# COMMAND ----------

# MAGIC %md
# MAGIC ### write into silver table

# COMMAND ----------

display(df)

# COMMAND ----------

df.write \
  .mode("overwrite") \
  .option("overwriteSchema", "true") \
  .format("delta") \
  .saveAsTable("medical_insurance.silver.patient_silver")

# COMMAND ----------

# MAGIC %sql
# MAGIC select * from medical_insurance.silver.patient_silver

# COMMAND ----------

