# Databricks notebook source
# include the silver_utils
import sys
sys.path.append('/Workspace/Users/mommensabry@gmail.com/Medical_Insurance_Analytics/lakehouse/libs')
from silver_utils import *

# COMMAND ----------

df = spark.table("medical_insurance.default.medical_record")

# COMMAND ----------

df = (
    df.transform(lambda d: remove_duplicates(d, ["record_id"]))
      .transform(trim_all_string_columns)
      .transform(replace_null_strings)
      .transform(replace_blank_date)
)

# COMMAND ----------

df.write \
  .mode("overwrite") \
  .option("overwriteSchema", "true") \
  .format("delta") \
  .saveAsTable("medical_insurance.silver.medical_record_silver")