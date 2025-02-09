import csv
from bs4 import BeautifulSoup
import pandas as pd
import requests
import re

#I think HD was released 734 days ago, so Im setting this a bit higher to be safe
from scipy.cluster.hierarchy import leaders

DAYS = 750

#1: get top 100 players IDs
html = requests.get("https://hyprd.mn/leaderboards")
soup = BeautifulSoup(html.content, "html.parser")
t = soup.find('table', {'class:', 'leaderboard'})

# [[rank, username, hd_id, score, run_link], [.....]]
a = t.find_all('a')[0::2]
b = t.find_all('a')[1::2]

lb = {}
# a is user id and username
# b is run id and score
for i in range(1000):
    uid = a[i].attrs.get("href").rfind("/")
    uid = a[i].attrs.get("href")[uid + 1::]
    rlink = b[i].attrs.get("href").rfind("/")
    rlink = b[i].attrs.get("href")[rlink + 1::]
    lb[uid] = {'rank': i + 1, 'username': a[i].text, 'score': b[i].text, 'run_link': rlink}

top_100_ids = list(lb)[:100]

leaderboard_data = {}

#2: get their per-day PB history
for i in range(100):
    c_id = top_100_ids[i]
    html = requests.get("https://hyprd.mn/user/" + c_id)
    soup = BeautifulSoup(html.content, "html.parser")
    t = soup.find('table', {'class:', 'pbhistory'})
    pbs = [0] * DAYS
    scores = t.find_all("td")[0::3]
    dates = t.find_all("td")[2::3]
    for s in range(len(scores)):
        pb = float(scores[s].a.text)
        d = 0
        # special case to exclude hours
        if dates[s].text.split(" ")[1] == 'days':
            d = int(dates[s].text.split(" ")[0])
        if d < DAYS and pb > pbs[d]:
            pbs[d] = pb

    pbs.reverse()
    cpb = -1
    for d in range(DAYS):
        if pbs[d] > cpb:
            cpb = pbs[d]
        else:
            pbs[d] = cpb

    leaderboard_data[lb[c_id]['username']] = pbs

df = pd.DataFrame(leaderboard_data)
df.to_csv("leaderboard_history.csv")
