# Scouting App: Student Guide

This guide covers the parts of the scouting app that work the same every season. The match and pit scouting forms change with each year's game, so they have their own guide.

Everything is in the menu: tap **☰** in the top-left corner.

---

## 1. Settings (do this first)

The app opens on Settings. Before your first match:

1. **Scouter name.** Type your name, so your team can see who scouted what. Your pick list is also saved under this name.
2. **Secret team key.** Your mentors will give you this. It keeps your team's data separate from other teams that use the app. Every scout on the team has to use the same key.
3. **Event.** Type part of the event's name (or its code, like `2026miwmi`) and pick it from the list. The app then loads the event's teams and match schedule by itself.

Once an event is picked, a row shows how many teams are loaded. Open it to see their numbers, or to reload them if the team list changed.

The rest is up to you:

- **Scouting:** *Scrollable scouting layout* (one long page instead of tabs), *Haptic feedback* (a buzz on every counter tap), and *Confetti*.
- **Appearance:** light, dark or system mode, a theme color, and a *Dyslexia-friendly font* (OpenDyslexic) for the whole app.
- **Season:** at the very bottom. You'll almost never need to change it.

Your settings are saved on the device. The menu shows your name and event under **Settings**, so you can check them at a glance.

---

## 2. Scout Match and Scout Pit

These forms change every year with the game. **See this year's scouting guide** for how to fill them out.

What doesn't change is what happens when you press Submit: see *Held Data* below.

## 3. Robot Note

A quick note about any robot, any time: something you saw in the pits, in the queue, or in a match you weren't assigned to.

1. Pick the team (type its number or name).
2. Write what you saw.
3. Press **Submit**.

Notes show up in that team's **Team Details** under Pit scouting → Robot notes.

---

## 4. Held Data (no signal? no problem)

Gyms and arenas often have bad or no Wi-Fi or cell signal. The app is built for that.

- Everything you submit (match, pit or robot note) is **saved on your device first**, then uploaded.
- If there's no connection, you'll see an orange bar: *"Saved on this device – will upload."* Keep scouting.
- The **Held Data** item in the menu shows a number when anything is waiting to upload.
- Held items upload **by themselves** when a connection comes back: when the app opens, when you come back to the tab, when the device goes back online, and about once a minute while anything is waiting.
- In a hurry? Open **Held Data** and press **Upload now**.
- If an upload is refused, the item stays held and shows the reason in red. Tell your scouting lead.

**One rule:** until your held data has uploaded, your device has the **only copy**. Don't clear your browser data, uninstall the app, or delete held items until the count is zero.

---

## 5. Management

These are mostly for the one or two people running scouting.

- **Scouting Status:** every match, with one column per robot (B1–B3, R1–R3). A green check means someone scouted that robot; a red X means nobody did; a number means more than one person did. Tap a mark to see who scouted it. If the schedule isn't loaded yet, press *Load match schedule*.
- **Pit Status:** every team, and how many pit scouting results it has. Filter to *Unscouted* to see who still needs a visit.

---

## 6. Analytics

Analytics turns everyone's scouting, plus official results from The Blue Alliance, into answers. The app keeps a copy of each screen's data, so it works offline too; tap the refresh button to get the latest.

**Tip:** the small **ⓘ** next to a team number opens that team's details, almost anywhere in the app.

### Match Breakdowns
Every match: the teams on each alliance, the final score, and the ranking points (RP) each alliance earned. Tap a match to open its full score breakdown. The chips at the top show quals, playoffs, team names, and each team's OPR.

### Rankings
The official event rankings. Tap any column heading to sort by it; tap it again to reverse the order. On a phone, the table scrolls sideways while Rank and Team stay put.

### Team Details
Everything about one team on one page:

- **Record**, ranking points per match, average score and how many matches we scouted.
- **Pit scouting**, including robot notes.
- **Scouted averages**, each with the event average and where this team ranks.
- **OPR**: an estimate of how many points the team adds to its alliance, from official qualification results.
- **Similar teams**: the teams whose numbers look most like this one's, and what sets it apart.
- **Matches**: every match the team played.

Collapse sections you don't need, or move them up and down with the ⇅ button. The app remembers your layout.

### Head to Head
Compare two to six teams side by side. Add teams by number. Three sections, which you can open, close and reorder:

- **Official results:** a table, then every match they played, with your teams marked.
- **Pit scouting:** their pit data side by side.
- **Dimensions:** every stat as a line from the lowest team at the event to the highest, with a colored dot for each of your teams. The biggest differences come first.

Your teams are saved for the event, so they're still there when you come back.

### Pick List
The team's alliance selection list, built together. Changes show up for everyone within seconds.

- **My List:** your own ranking. Drag teams into your order, or into *Do Not Pick*. It's saved under your scouter name.
- **Board:** everyone's lists combined. Spot #1 goes to the team the most people put first, spot #2 to the team the most people put second, and so on. The bar shows how many people agree on that spot. Use *Min votes* and *Participants* to filter.
- **Other Lists:** everyone else's lists, side by side.
- **Taken:** during alliance selection, mark teams that get picked as *taken*; it updates for everyone.

Tap a team to add your own notes about it.

### Clusters
Sorts teams into groups that play alike, based on their stats (the math is called *k-means*). Each group gets a chart: choose which stat goes on each axis, and how many groups to make. Tap a team to find it on the chart. Below each chart, see how the group compares to the event average.

### Dimensions
Chooses which stats the clustering uses, and how much each one counts (its weight). It's for stats fans: the team default works fine, and you don't need to change it. *Publish as team default* changes it for everyone, so check with your scouting lead first.

---

## Quick troubleshooting

| Problem | Fix |
|---|---|
| "No teams loaded" | Go to Settings and check the event. Open the teams row and press *Reload teams*. |
| My data isn't showing up for others | Check **Held Data**. If items are waiting, find a signal and press *Upload now*. |
| Analytics screens are empty | Check the secret team key in Settings, then tap refresh. |
| My pick list is gone | Check your scouter name: lists are saved under it, spelled exactly the same. |
