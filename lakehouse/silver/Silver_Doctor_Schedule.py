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

df = spark.table("medical_insurance.default.doctor_schedule")

# COMMAND ----------

# MAGIC %md
# MAGIC ### Silver Transformation

# COMMAND ----------

df = (
    df.transform(lambda d: remove_duplicates(d, ["schedule_id"]))
      .transform(replace_null_strings)
)
replace_blank_date(df)

# COMMAND ----------

# MAGIC %md
# MAGIC ### write into silver table

# COMMAND ----------

df.write \
  .mode("overwrite") \
  .option("overwriteSchema", "true") \
  .format("delta") \
  .saveAsTable("medical_insurance.silver.doctor_schedule_silver")