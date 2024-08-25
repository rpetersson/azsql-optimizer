import streamlit as st
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
st.set_page_config(layout="wide")

st.title('Azure SQL Right Sizing Tool')

# Get data.
df = pd.read_csv('data.csv')

#Highlight min column DTU Consumption Percentage evry value below 0.5

st.dataframe(df.style.background_gradient(cmap='viridis', low=0.00, high=1, subset=['DTU Used Average']))

