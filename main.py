import streamlit as st
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
from azure.identity import DefaultAzureCredential
import subprocess

# Add Azure Default Credentials
credential = DefaultAzureCredential()

# Execute PowerShell script
def execute_powershell_script(script_path):
    result = subprocess.run(["powershell", "-File", script_path], capture_output=True, text=True)
    return result.stdout, result.stderr

# Example usage
script_output, script_error = execute_powershell_script("./script.ps1")
if script_error:
    st.error(f"Error executing PowerShell script: {script_error}")
else:
    st.success("PowerShell script executed successfully")
    st.text(script_output)

st.set_page_config(layout="wide")

# SKU Pricing lookup table as dataframe

# Sku pricing for Gen5 and Gen4 title
st.title('Database SKU Pricing Overview')

sku_pricing = pd.DataFrame({
    'databaseSkuName': ['GP_Gen5_2', 'GP_Gen5_4', 'GP_Gen5_8', 'GP_Gen5_16', 'GP_Gen5_32', 'GP_Gen5_48', 'GP_Gen5_80', 'BC_Gen5_2', 'BC_Gen5_4', 'BC_Gen5_8', 'BC_Gen5_16', 'BC_Gen5_32', 'BC_Gen5_48', 'BC_Gen5_80'],
    'vCores': [2, 4, 8, 16, 32, 48, 80, 2, 4, 8, 16, 32, 48, 80],
    'Memory': [5, 10, 20, 40, 80, 120, 200, 5, 10, 20, 40, 80, 120, 200],
    'DTUs': [5, 10, 20, 40, 80, 120, 200, 5, 10, 20, 40, 80, 120, 200],
    'Price': [0.011, 0.022, 0.044, 0.088, 0.176, 0.264, 0.44, 0.011, 0.022, 0.044, 0.088, 0.176, 0.264, 0.44]
})

sku_pricing_dtu = pd.DataFrame({
    'DTUs': ['S0', 'S1', 'S2', 'S3', 'S4', 'S6', 'S7', 'S9', 'S12'],
    'Included storage': ['10', '20', '50', '100', '200', '400', '800', '1,600', '3,000'],
    'Max storage': ['250 GB', '250 GB', '250 GB', '1 TB', '1 TB', '1 TB', '1 TB', '1 TB', '1 TB'],
    'Price for DTUs and included storage': ['0.0202', '0.0404', '0.1009', '0.2017', '0.4033', '0.8066', '1.6130', '3.2260', '6.0488']
})

# Convert Price column Price for DTUs and included storage from per hour to monthly
sku_pricing_dtu['Price for DTUs and included storage'] = sku_pricing_dtu['Price for DTUs and included storage'].astype(float) * 24 * 31

# Display both DTU and SKU pricing horizontaly
rows = st.columns(2)
rows[0].dataframe(sku_pricing)
rows[1].dataframe(sku_pricing_dtu)

st.title('Database DTU Consumption Overview')

# Get data.
df = pd.read_csv('data.csv')

# Add new column DTU Used Percentage
df['DTU Used Percentage'] = (df['DTU Used Average'] / df['DTU Limit']) * 100

# Add new column, lookup price for column CurrentServiceObjectiveName from dataframe sku_pricing_dtu
df['Price'] = df['CurrentServiceObjectiveName'].map(sku_pricing_dtu.set_index('DTUs')['Price for DTUs and included storage'])

# Drop column sql_instance_memory_percent
df.drop(columns=['sql_instance_memory_percent'], inplace=True)

# Drop column sql_instance_cpu_percent
df.drop(columns=['Percentage CPU'], inplace=True)

# FILTER
# Only display standard sku
filtered_df = df[df['databaseSkuName'].str.startswith('Standard')]

# Highlight min column DTU Consumption Percentage evry value below 0.5
st.dataframe(filtered_df.style.background_gradient(cmap='viridis', low=0.00, high=1, subset=['DTU Used Average']))

# Display average DTU Used Percentage over all databases
st.write('Average DTU Used Percentage over all databases %:', filtered_df['DTU Used Percentage'].mean())

# Display number of databases
st.write('Number of databases:', filtered_df['DatabaseName'].count())

# Summerize Price for all filtered databases
st.write('Total Price for all databases:', filtered_df['Price'].sum())

st.title('Database Vcore Consumption Overview')

# Get data.
df = pd.read_csv('data.csv')

# Filteraway all rows where databaseSkuName does not start with GP
df = df[df['databaseSkuName'].str.startswith('GP')]

# Display the dataframe
st.dataframe(df.style.background_gradient(cmap='viridis', low=0.00, high=1, subset=['DTU Used Average']))

# Display average Percentage CPU over all databases
st.write('Average Percentage CPU over all databases %:', df['Percentage CPU'].mean())

# Display number of databases
st.write('Number of databases:', df['DatabaseName'].count())

st.markdown("""---""")

st.title('Database SKU Overview')

# Get data.
df = pd.read_csv('data.csv')

# Display streamlit bar chart with amount on y-axis and databaseSkuName on x-axis
chart_data = pd.DataFrame(df)
st.bar_chart(chart_data['databaseSkuName'].value_counts())