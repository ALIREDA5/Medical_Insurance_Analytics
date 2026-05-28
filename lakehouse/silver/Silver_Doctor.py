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

df = spark.table("medical_insurance.default.doctor")

# COMMAND ----------

# MAGIC %md
# MAGIC ### Silver Transformation

# COMMAND ----------

# Rename column phone to doctor_phone
df = rename_columns(df, {"phone": "doctor_phone"})

# concate first_name and last_name to doctor_name
df = concat_columns(df, {"doctor_name": ["first_name", "last_name"]})

# drop columns first_name and last_name
df = df.drop("first_name", "last_name")

# COMMAND ----------

df = (
    df.transform(lambda d: remove_duplicates(d, ["doctor_id"]))
      .transform(trim_all_string_columns)
      .transform(replace_null_strings)
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### write into silver table

# COMMAND ----------

df.write \
  .mode("overwrite") \
  .option("overwriteSchema", "true") \
  .format("delta") \
  .saveAsTable("medical_insurance.silver.doctor_silver")