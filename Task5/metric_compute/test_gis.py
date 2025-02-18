import geopandas
import os
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
from LoadData import ReadHead

d_project = os.path.dirname(__file__)
d_mwp_cwf = os.path.dirname(os.path.dirname(d_project))
d_mwp_ihm = os.path.join(os.path.dirname(d_mwp_cwf),'MWP-IHM')
d_runihm = os.path.join(d_mwp_ihm,'INTB2_bp424')

rh = ReadHead(d_runihm)
cids = [43064,44064,45065]
colname = [f'{i:06}' for i in cids]
x,t,l = rh.readHeadByCellIDs(None, layers=[1,3], CIDs=cids)

df = pd.DataFrame(x, columns=colname)
df['Layer'] = l
df['TimeStep'] = t

# Add calendar and weekstart flag
df = pd.merge(rh.Calendar, df, on='TimeStep', how='right')

# compute weekly average
df = df.groupby(['WeekStart','Layer']).mean()

# restore ['WeekStart','Layer'] columns
df['WeekStart'] = df.index.get_level_values(0)
df['Layer'] = df.index.get_level_values(1)

# Unpivol by cell columns
df = pd.melt(df, id_vars=['WeekStart','Layer'], value_vars=colname, var_name='CellID')
df['Cell_n_Layer'] = [f'{i}({j})' for i,j in zip(df.CellID,df.Layer)]
df = df[df.value>-1e3]
fig = plt.figure(figsize=(13.5, 9.75))
sns.set_theme(style="darkgrid")

topo = [67.14,71.06,75.23]
# sns.scatterplot(data=df3, x='Date', y=colname, markers=False, s=0)
g = sns.lineplot(data=df, x='WeekStart', y='value', hue='Cell_n_Layer',
    style='Cell_n_Layer', dashes=[(1,0),(1,0),(1,0)])

xlim = [df.iloc[0,0],df.iloc[-1,0]]
TopoID = [f'topo({i})' for i in colname]
topoDF = pd.DataFrame(np.column_stack((
    np.array(xlim+xlim+xlim).reshape(-1,1),
    np.array([topo,topo]).reshape(-1, 1, order='F'),
    np.array([TopoID,TopoID]).reshape(-1, 1, order='F')
)), columns=['Date','Topo','TopoID'])
avgwl = df[['value','Cell_n_Layer']].groupby('Cell_n_Layer').mean()
avgwl['avgDWT'] = -avgwl['value']+np.array(topo+[topo[-1]])
print(avgwl)
avgwl
#                   value     avgDWT
# Cell_n_Layer                      
# 043064(3)     42.263348  24.876652
# 044064(3)     45.986805  25.073195
# 045065(1)     49.093941  26.136059
# 045065(3)     48.850315  26.379685
sns.lineplot(data=topoDF, x='Date', y='Topo', hue='TopoID',
    style='TopoID', dashes=[(1,1),(1,1),(1,1)])
g.legend(title='CellID-Layer', loc='upper right')
plt.xlabel('Date')
plt.ylabel('Waterlevel, ft NGVD')
plt.title('WRW-s')

svfilePath = os.path.join(d_project,f'WRW-s nearby Cells WL')
fig.savefig(svfilePath+'.pdf'
    , dpi=300, bbox_inches="tight", pad_inches=1, facecolor='auto', edgecolor='auto')



d_shapefile = os.path.join(d_mwp_cwf,'Shapefiles')

gdf_intbgrid = geopandas.read_file(os.path.join(d_shapefile,'INTBgrid.shp'))
ax = gdf_intbgrid.plot()
ax.set_title("INTB Grid")
plt.show()

exit(0)