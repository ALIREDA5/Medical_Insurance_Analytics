# Databricks notebook source
# MAGIC %md
# MAGIC ### Initialization

# COMMAND ----------

# include the silver_utils
import sys
sys.path.append('/Workspace/Users/mommensabry@gmail.com/Medical_Insurance_Analytics/lakehouse/libs')
from silver_utils import *

# COMMAND ----------

# MAGIC %md
# MAGIC ### Read Bronze table

# COMMAND ----------

df = spark.table("medical_insurance.default.department")
display(df)

# COMMAND ----------

# MAGIC %md
# MAGIC ### Silver Transformation

# COMMAND ----------

df = (
    df.transform(lambda d: remove_duplicates(d, ["department_id"]))
      .transform(trim_all_string_columns)
      .transform(replace_null_strings)
      .transform(replace_null_numeric)
)
replace_blank_date(df)

# add zero to phone numbers
df = df.withColumn("manager_phone", concat(lit("0"), col("manager_phone")))
df = format_egypt_phone_numbers(df, ["manager_phone"])


# edit thr floor_number data type to int
df = df.withColumn("floor_number", col("floor_number").cast("int"))

display(df)

# COMMAND ----------

# MAGIC %md
# MAGIC ### write into silver table

# COMMAND ----------

df.write \
  .mode("overwrite") \
  .option("overwriteSchema", "true") \
  .format("delta") \
  .saveAsTable("medical_insurance.silver.department_silver")

# COMMAND ----------

df.display()