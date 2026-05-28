# Databricks notebook source
# MAGIC %md
# MAGIC ## Initialization

# COMMAND ----------

# include the silver_utils
import sys
sys.path.append('/Workspace/Users/mommensabry@gmail.com/Medical_Insurance_Analytics/lakehouse/libs')
from silver_utils import *

# COMMAND ----------

# MAGIC %md
# MAGIC ## Read Bronze table

# COMMAND ----------

df = spark.table("medical_insurance.default.hospital")

# COMMAND ----------

# MAGIC %md
# MAGIC ### Silver Transformation

# COMMAND ----------

# Rename column phone to hospital_phone
df = rename_columns(df, {"phone": "hospital_phone"})

# COMMAND ----------

df = (
    df.transform(lambda d: remove_duplicates(d, ["hospital_id"]))
      .transform(trim_all_string_columns)
      .transform(replace_null_strings)
      .transform(lambda d: format_egypt_phone_numbers(d, ['manager_phone']))
      .transform(lambda d: format_egypt_phone_numbers(d, ['hospital_phone']))
)

# COMMAND ----------

df = df.withColumn("manager_phone",
    when(col("manager_name") == "Dalia Zawawi",     "+20-100-123-4567")
    .when(col("manager_name") == "Eman Mahrous",     "+20-101-234-5678")
    .when(col("manager_name") == "Marwan El-Hariry", "+20-102-345-6789")
    .when(col("manager_name") == "Shimaa Hamza",     "+20-109-456-7890")
    .when(col("manager_name") == "Saad El-Sayed",    "+20-111-567-8901")
    .when(col("manager_name") == "Tarek El-Naggar",  "+20-112-678-9012")
    .when(col("manager_name") == "Salma Mohamed",    "+20-120-789-0123")
    .when(col("manager_name") == "Reda El-Husseiny", "+20-122-890-1234")
    .otherwise(col("manager_phone"))
).withColumn("manager_email",
    when(col("manager_name") == "Dalia Zawawi",     "alireda.elec@gmail.com")
    .when(col("manager_name") == "Eman Mahrous",     "basmazakaria112@gmail.com")
    .when(col("manager_name") == "Marwan El-Hariry", "mommensabry@gmail.com")
    .when(col("manager_name") == "Shimaa Hamza",     "saif2015saif1@gmail.com")
    .when(col("manager_name") == "Saad El-Sayed",    "eng.mayarmaghawry@gmail.com")
    .when(col("manager_name") == "Tarek El-Naggar",  "karimanibrahemmostafa@gmail.com")
    .when(col("manager_name") == "Salma Mohamed",    "shaimaahesham647@gmail.com")
    .when(col("manager_name") == "Reda El-Husseiny", "diab.saeed.2020@vet.usc.edu.eg")
    .otherwise(col("manager_email"))
).withColumn("hospital_phone",
    when(col("hospital_id") == "H002", "+20-100-234-5678")
    .when(col("hospital_id") == "H004", "+20-101-345-6789")
    .when(col("hospital_id") == "H005", "+20-102-456-7890")
    .when(col("hospital_id") == "H008", "+20-109-567-8901")
    .when(col("hospital_id") == "H001", "+20-111-678-9012")
    .when(col("hospital_id") == "H006", "+20-112-789-0123")
    .when(col("hospital_id") == "H007", "+20-120-890-1234")
    .when(col("hospital_id") == "H003", "+20-122-901-2345")
    .otherwise(col("hospital_phone"))
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### write into silver table

# COMMAND ----------

df.write \
  .mode("overwrite") \
  .option("overwriteSchema", "true") \
  .format("delta") \
  .saveAsTable("medical_insurance.silver.hospital_silver")

# COMMAND ----------

df.display()