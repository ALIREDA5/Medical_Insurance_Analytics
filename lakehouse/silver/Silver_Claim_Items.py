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

df = spark.table("medical_insurance.default.claim_item")

# COMMAND ----------

# MAGIC %md
# MAGIC ### Silver Transformation

# COMMAND ----------

df = df.withColumnRenamed("quantity", "item_quantity")

# COMMAND ----------

df = (
    df.transform(lambda d: remove_duplicates(d, ["claim_item_id"]))
      .transform(replace_null_strings)
      .transform(replace_null_numeric)
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### write into silver table

# COMMAND ----------

df.write \
  .mode("overwrite") \
  .option("overwriteSchema", "true") \
  .format("delta") \
  .saveAsTable("medical_insurance.silver.claim_items_silver")