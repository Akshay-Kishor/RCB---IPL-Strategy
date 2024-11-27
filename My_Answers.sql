use ipl;

------ This View has ball by ball, wkts and runs scored

Create view ball_by_ball_run_wkts as
select 
    b.Match_id,
    b.Over_id,
    b.Ball_id,
    b.Innings_no,
    b.Team_Batting,
    b.Team_Bowling,
    b.Striker_Batting_position,
    b.Striker,
    b.Non_Striker,
    b.Bowler,
    COALESCE(bs.Runs_Scored, 0) AS Runs_Scored,
    COALESCE(wt.Player_out, 0) AS Player_out,
    COALESCE(wt.Kind_out, 0) AS Wicket_type
    
from ball_by_ball_run_wkts b
left join batsman_scored bs
on b.Match_id = bs.Match_id
and b.Over_id = bs.Over_id
and b.Ball_Id = bs.Ball_id
and b.Innings_no = bs.Innings_no

left join wicket_taken wt
on b.Match_id = wt.Match_id
and b.Ball_Id = wt.Ball_id
and b.Over_id = wt.Over_id
and b.Innings_no = wt.Innings_no;

------ This View has ball by ball, wkts and runs scored & Seasons

Create View ball_by_ball_with_season as
select
    b.Match_id,
    b.Over_id,
    b.Ball_id,
    b.Innings_no,
    b.Team_Batting,
    b.Team_Bowling,
    b.Striker_Batting_position,
    b.Striker,
    b.Non_Striker,
    b.Bowler,
    b.Runs_Scored,
    b.Player_out,
    b.Wicket_type,
    m.Season_id,
    m.Venue_id,
    m.Match_Winner
    
from ball_by_ball_run_wkts b
left join matches m
on b.Match_id = m.Match_id;


----- 2) What is the total number of run scored in 1st season by RCB (bonus : also include the extra runs using the extra runs table)

with Legal_Runs as
(select Sum(Runs_Scored) as Legal_Runs from ball_by_ball_with_season
where Season_id = 1
and Team_Batting = 2),

Extra_Runs_New as
(select sum(er.Extra_Runs) as Extras from ball_by_ball_with_season as bs

left join extra_runs as er
on bs.Match_id = er.Match_id
and bs.Over_id = er.Over_id
and bs.Ball_id = er.Ball_id
and bs.Innings_no = er.Innings_no

where bs.Season_id = 1
and bs.Team_Batting = 2)

select ((select * from Legal_Runs) + (select * from Extra_Runs_New)) as Total_Runs;


----- 3) How many players were more than age of 25 during season 2

with season_2 as (
select Season_Year
from Season
where Season_Id = 2
),

players_above_25 as (
select P.Player_Id, P.Player_Name, 
timestampdiff(year, P.DOB, concat((select Season_Year from season_2), '-01-01')) as Age_At_Season_2
from Player P
having Age_At_Season_2 > 25
)

select count(*) as Players_Above_25
from players_above_25;

---- 4) How many matches did RCB win in season 1 

select count(distinct Match_id) as Match_won from matches 
where Season_Id = 1 and
Match_Winner = 2 and
(Team_1 = 2 or Team_2 = 2);


----- 5) List top 10 players according to their strike rate in last 4 seasons
with Striker_Rate as
(select Striker, round(((sum(Runs_Scored) / Count(Ball_id))*100),2) as "Strike_Rate" from ball_by_ball_with_season
where Season_id in (9,8,7,6)
group by Striker
having count(Ball_id) > 100
order by Strike_Rate desc)

select 
	rank() over(order by sr.Strike_Rate desc) as "Ranking",
	p.Player_name, 
	sr.Strike_Rate
from Striker_Rate sr
join player as p
on sr.Striker = p.Player_Id
limit 10;


----- 6) What is the average runs scored by each batsman considering all the seasons?

with Striker_Wise as
(select Striker, sum(Runs_Scored) as Total_Runs, count(distinct Match_id) as Matches_Played from ball_by_ball_with_season
group by Striker)

select 
	p.Player_name, 
	round((sw.Total_Runs / sw.Matches_Played),2) as "Avg_Runs"
from Striker_Wise sw
join player as p
on sw.Striker = p.Player_Id
order by Avg_Runs desc;


----- 7) What are the average wickets taken by each bowler considering all the seasons?
with Bowler_WKts as
(select Bowler, count(Player_out) as Total_Wkts from ball_by_ball_with_season
where Player_out != 0
group by Bowler),

Bowler_Matches as
(select Bowler,count(distinct Match_id) as Matches_Played from ball_by_ball_with_season group by Bowler),

Final_View as
(select
		bm.Bowler,
        coalesce(bw.Total_Wkts,0) as Total_Wkts,
        bm.Matches_Played
from Bowler_Matches bm
left join Bowler_WKts bw
on bm.Bowler = bw.Bowler)


select 
	p.Player_name, 
	round((fv.Total_Wkts / fv.Matches_Played),2) as "Avg_Wkts"
from Final_View fv
join player as p
on fv.Bowler = p.Player_Id
order by Avg_Wkts desc;


----- 8) List all the players who have average runs scored greater than overall average and who have taken wickets greater than overall average

with Striker_Wise as
(select Striker, round((sum(Runs_Scored)/count(distinct Match_id)),2) as Avg_Runs from ball_by_ball_with_season   
group by Striker),

Bowler_WKts as
(select Bowler, count(Player_out) as Total_Wkts from ball_by_ball_with_season
where Player_out != 0
group by Bowler),

Bowler_Matches as
(select Bowler,count(distinct Match_id) as Matches_Played from ball_by_ball_with_season group by Bowler),

Bowler_Final_View as
(select
		bm.Bowler,
        (coalesce(bw.Total_Wkts,0) / bm.Matches_Played) as Avg_Wkts
from Bowler_Matches bm
left join Bowler_WKts bw
on bm.Bowler = bw.Bowler),

Final_View as
(select sw.Striker as Player_ID, sw.Avg_Runs, bw.Avg_Wkts from Striker_Wise as sw
join Bowler_Final_View as bw
on sw.Striker = bw.Bowler
where sw.Avg_Runs > (select avg(Avg_Runs) as Overall_Avg_Runs from Striker_Wise)
and bw.Avg_Wkts > (select avg(Avg_Wkts) as Overall_Avg_Wkts from Bowler_Final_View))

select p.Player_Name, fv.Avg_Runs, round(fv.Avg_Wkts,2) from Final_View as fv
join player as p
on fv.Player_ID = p.Player_Id
order by Avg_Runs desc, Avg_Wkts desc;


----- 9) Create a table rcb_record table that shows wins and losses of RCB in an individual venue.
CREATE TABLE Venue_Match_Stats (
    Venue_Name VARCHAR(255),
    Won_Matches INT,
    Lost_Matches INT
)

with rcb_tot as
(select Venue_Id, count(distinct Match_Id)  as Total_Matches from matches
where Team_1 = 2 or Team_2 = 2
group by Venue_Id),

rcb_won as
(select Venue_Id, count(distinct Match_Id) as Won from matches
where Match_Winner =2 and
(Team_1 = 2 or Team_2 = 2)
group by Venue_Id),

Venue_Wise as
(select rt.Venue_Id, rt.Total_Matches, coalesce(rw.Won,0) as Won_Matches from rcb_tot as rt
left join rcb_won as rw
on rt.Venue_Id = rw.Venue_Id),

VenueStats as
(SELECT v.Venue_Name, vw.Won_Matches, (vw.Total_Matches - vw.Won_Matches) AS Lost_Matches 
FROM Venue_Wise vw
JOIN Venue v ON vw.Venue_Id = v.Venue_Id
ORDER BY vw.Total_Matches DESC)


INSERT INTO Venue_Match_Stats (Venue_Name, Won_Matches, Lost_Matches)
Values 
(SELECT Venue_Name, Won_Matches, Lost_Matches
FROM VenueStats)


select * from VenueStats;

----- 10)	What is the impact of bowling style on wickets taken.

With Bowler_Wise_Wkts as
(select Bowler, count(player_out) as Tot_Wkts from ball_by_ball_with_season
where player_out != 0
group by Bowler
order by Tot_Wkts desc)

select 
	bs.Bowling_skill,
	sum(bw.Tot_Wkts) as "Total_Wkts"
from Bowler_Wise_Wkts bw
join player as p
on bw.Bowler = p.Player_Id

join bowling_style bs
on p.Bowling_skill = bs.Bowling_Id

group by bs.Bowling_skill
order by Total_Wkts desc;


-------- 11) Write the sql query to provide a status of whether the performance of the team better than the previous year performance
--------     on the basis of number of runs scored by the team in the season and number of wickets taken

with Run_Chart as
(select 
	Season_id, 
    Team_Batting, 
    sum(Runs_Scored) as "Tot_Runs",
    lag(sum(Runs_Scored)) over(order by Season_id rows between 1 preceding and current row) as "Previous_Year_Runs"
from ball_by_ball_with_season
where Team_Batting = 2
group by Season_id, Team_Batting
order by Season_id ),

Bowl_Chat as
(select 
	Season_id, 
    Team_Bowling, 
    count(Player_out) as "Tot_Wkts",
    lag(count(Player_out)) over(order by Season_id rows between 1 preceding and current row) as "Previous_Year_Wkts"
from ball_by_ball_with_season
where Team_Bowling = 2 and Player_out != 0
group by Season_id, Team_Bowling
order by Season_id)

select 
	r.Season_id,
    r.Tot_Runs,
    r.Previous_Year_Runs,
    w.Tot_Wkts,
    w.Previous_Year_Wkts,
    case
    WHEN Previous_Year_Runs is null or Previous_Year_Wkts is null then 'Blank'
    when r.Tot_Runs > r.Previous_Year_Runs and w.Tot_Wkts > w.Previous_Year_Wkts then "Better_Performance"
    else "Not_Good"
    end as "Status"
from Run_Chart as r
join Bowl_Chat as w
on r.Season_id = w.Season_id;

------ 12)	Can you derive more KPIs for the team strategy if possible?

##### 1.	Year-over-Year Improvement (Runs & Wickets)
with Run_Chart as
(select 
	Season_id, 
    Team_Batting, 
    sum(Runs_Scored) as "Tot_Runs",
    lag(sum(Runs_Scored)) over(order by Season_id rows between 1 preceding and current row) as "Previous_Year_Runs"
from ball_by_ball_with_season
where Team_Batting = 2
group by Season_id, Team_Batting
order by Season_id ),


Bowl_Chat as
(select 
	Season_id, 
    Team_Bowling, 
    count(Player_out) as "Tot_Wkts",
    lag(count(Player_out)) over(order by Season_id rows between 1 preceding and current row) as "Previous_Year_Wkts"
from ball_by_ball_with_season
where Team_Bowling = 2 and Player_out != 0
group by Season_id, Team_Bowling
order by Season_id)

select 
	r.Season_id,
    r.Tot_Runs,
    r.Previous_Year_Runs,
    concat(round(coalesce(((r.Tot_Runs / r.Previous_Year_Runs - 1)*100),"BLANK"),0), "%") as "Run_Improvement_Percent",
    w.Tot_Wkts,
    w.Previous_Year_Wkts,
    concat(round(coalesce(((w.Tot_Wkts / w.Previous_Year_Wkts - 1)*100),"BLANK"),0), "%") as "Wickets_Improvement_Percent"
from Run_Chart as r
join Bowl_Chat as w
on r.Season_id = w.Season_id;

###### 2.	Batting Performance Metrics

with overall_View as
(select 
	Season_id, 
    Team_Batting,
    sum(Runs_Scored) as "Overall_Runs"
from ball_by_ball_with_season
where Team_Batting = 2
group by Season_id, Team_Batting
order by Season_id),

boundary_View as
(select 
	Season_id, 
    Team_Batting,
    sum(Runs_Scored) as "Boundary_Runs"
from ball_by_ball_with_season
where Team_Batting = 2
and Runs_Scored in (4,6)
group by Season_id, Team_Batting
order by Season_id)

select 
	o.Season_id,
	o.Overall_Runs,
    b.Boundary_Runs,
    round(((b.Boundary_Runs/o.Overall_Runs)*100),2) as "Percent_Boundary"
from overall_View as o
left join boundary_View as b
on o.Season_id = b.Season_id;

####### 3. Match Impact Metrics

with Defend as
(select
	count(distinct match_id) as "Defending_Wins"
from matches
where Win_type = 1
and (Team_1 = 2
or Team_2 = 2)),

Chase as
(select
	count(distinct match_id) as "Chasing_Wins"
from matches
where Win_type = 2
and (Team_1 = 2
or Team_2 = 2)),

Total as
(select
	count(distinct match_id) as "Chasing_Wins"
from matches
where Team_1 = 2
or Team_2 = 2)

select round(((Select * from Defend) / (Select * from Total))*100,2) as "Defend_Win_Percent",
round(((Select * from Chase) / (Select * from Total))*100,2) as "Chase_Win_Percent";

------- 13)	Using SQL, write a query to find out average wickets taken by each bowler in each venue. Also rank the gender according to the average value.

With Venue_view_wkts as
(select 
	Venue_id, 
	Bowler, 
	count(player_out) as Tot_Wkts 
from ball_by_ball_with_season
where Team_Bowling = 2
and Player_out != 0
group by Venue_id, Bowler
order by Venue_id),

Venue_view_tot as
(select 
	Venue_id, 
	Bowler, 
	count(distinct match_id) as Tot_Match
from ball_by_ball_with_season
where Team_Bowling = 2
group by Venue_id, Bowler
order by Venue_id),

Venue_view_Final as
(select 
	vt.Venue_id,
    vt.Bowler,
    round((coalesce(vw.Tot_Wkts,0) / vt.Tot_Match),2) as Avg_Wkts
from Venue_view_tot as vt
left join Venue_view_wkts as vw
on vt.Venue_id = vw.Venue_id
and vt.Bowler = vw.Bowler
)

select 
	v.Venue_id,
    a.Venue_Name,
    p.Player_name,
    v.Avg_Wkts,
    rank() over(partition by v.Venue_id order by v.Avg_Wkts desc) as "Ranking"
from Venue_view_Final as v
left join venue as a
on v.Venue_id = a.Venue_id

left join player as p
on v.bowler = p.Player_id

where v.Avg_Wkts != 0
order by v.Venue_id, Ranking;

--- 14)	Which of the given players have consistently performed well in past seasons? (will you use any visualisation to solve the problem)

with Tot_Runs as
(select Season_id, Striker, sum(Runs_Scored) as Tot_Runs from ball_by_ball_with_season
where Team_batting = 2
group by Season_id, Striker
order by Season_id, sum(Runs_Scored) desc)

######## Below Query is providing 2 batsman name who has contributed across seasons

select
    p.Player_Name,
    count(p.Player_Name) as "Scored_More_than_300"
from Tot_Runs as tr
left join player as p
on tr.Striker = p.Player_Id
where tr.Tot_Runs > 300
group by p.Player_Name
having count(p.Player_Name) != 0
order by Scored_More_than_300 desc;

####### Now Trying to Fetch the Best Performing Bowler
with Bowler_wkts as
(select
	Season_id,
	Bowler, 
	count(player_out) as Tot_Wkts 
from ball_by_ball_with_season
where Team_Bowling = 2
and Player_out != 0
group by Season_id, Bowler)

######## Below Query is providing 4 bowler name who has contributed across seasons
select
    p.Player_Name,
    count(p.Player_Name) as "Taken_more_than_10Wkts"
from Bowler_wkts as bw
left join player as p
on bw.Bowler = p.Player_Id
where bw.Tot_Wkts > 10
group by p.Player_Name
having count(p.Player_Name) > 1
order by count(p.Player_Name) desc;


--------- 15)	Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?)

with Batsman_View as
(select 
	Venue_id,
	Striker,
    round(sum(Runs_Scored) / count(distinct Match_id),2) as Avg_Runs,
    count(distinct Match_id) as Matches_Played
from ball_by_ball_with_season
where Team_Batting = 2
group by Venue_id, Striker
having count(Runs_Scored) > 50)

select
	v.Venue_Name,
    p.Player_Name,
    bv.Avg_Runs,
    bv.Matches_Played
from Batsman_View as bv
left join player as p
on bv.Striker = p.Player_id

left join venue as v
on bv.Venue_id = v.Venue_id;



---------- Subjective 1) How does toss decision have affected the result of the match ? 
---------- (which visualisations could be used to better present your answer) And is the impact limited to only specific venues?


with Overall_Matches as
(select
	Venue_id,
    count(distinct Match_id) as Matches
from matches
where win_type in (1,2)
group by Venue_id),

Bowl_First as
(select
	Venue_id,
    count(distinct Match_id) as Bowl_Won
from matches
where win_type = 2
group by Venue_id),

Bat_First as
(select
	Venue_id,
    count(distinct Match_id) as Bat_Won
from matches
where win_type = 1
group by Venue_id)

select 
	v.Venue_name,
    a.Matches,
    round((coalesce(b.Bowl_Won,0) / a.Matches)* 100,0) as Bowl_First,
    round((coalesce(c.Bat_Won,0)  / a.Matches)* 100,0) as Bat_First
from Overall_Matches as a

left join Bowl_First as b
on a.Venue_id = b.Venue_id

left join Bat_First as c
on a.Venue_id = c.Venue_id

left join venue as v
on a.Venue_id = v.Venue_id;

################ Calculated the Percent of matches wherein Toss Winner has won the match

with Toss_Winner as
(select
	count(distinct Match_id) as Matches_Won
from matches
where Toss_Winner = Match_Winner),

Tot_matches as
(select count(distinct Match_id) as Tot_Matches from matches)

select round(((select * from Toss_Winner) / (Select * from Tot_matches) *100),2) as Toss_Win_Match_Win_Percent;


------- Subjective 2) Suggest some of the players who would be best fit for the team?

########## Considering all plyrs who are below 30 years of age

with My_Set_of_Players as
(select Player_Id, Player_Name,
	timestampdiff(year,DOB,"2017-01-01") as "Age"
from player
where timestampdiff(year,DOB,"2017-01-01") < 30),

########## Calculating Tot_RUns Scored

Runs_Scored as
(select Striker, sum(Runs_Scored) as Tot_Runs
from ball_by_ball_with_season
group by Striker),

########## Calcuating Total Wicktes taken

Wickets_Taken as
(select Bowler, count(player_out) as Wkts_taken
from ball_by_ball_with_season
where player_out != 0
group by Bowler),

########## Finding the Player name and who has scored more than 1500rs

Best_Batsman as
(select
	a.Player_Id,
    a.Player_Name,
    a.Age,
    coalesce(r.Tot_Runs,0) as "Tot_Run"
from My_Set_of_Players as a

left join Runs_Scored as r
on a.Player_Id = r.Striker
where r.Tot_Runs > 1500),

########## Finding the Player name and who has taken more than 80 wkts

Best_Bowler as
(select
	a.Player_Id,
    a.Player_Name,
    a.Age,
    coalesce(w.Wkts_taken,0) as "Wkts_Take"
from My_Set_of_Players as a

left join Wickets_Taken as w
on a.Player_Id = w.Bowler
where w.Wkts_taken > 80),

########## Joining both the batsman and bowler in a single table

Final_View as(
SELECT
	s.Player_id,
    s.Player_Name,
    s.Age,
    COALESCE(s.Wkts_Take, 0) AS Wkts_Take,
    COALESCE(t.Tot_Run, 0) AS Tot_Run
FROM 
    Best_Bowler s
LEFT JOIN 
    Best_Batsman t
ON 
    s.Player_Id = t.Player_Id

UNION

SELECT 
	t.Player_id,
    t.Player_Name,
    t.Age,
    COALESCE(s.Wkts_Take, 0) AS Wkts_Take,
    COALESCE(t.Tot_Run, 0) AS Tot_Run
FROM 
    Best_Bowler s
RIGHT JOIN 
    Best_Batsman t
ON 
    s.Player_Id = t.Player_Id),
    

########## Finding Batsman who are already in RCB

Batsman_Already_in_RCB as
(select Striker from ball_by_ball_with_season
where Season_id = 9 and Team_Batting = 2),

########## Finding Bwoler who are already in RCB

Bowler_Already_in_RCB as
(select Bowler from ball_by_ball_with_season
where Season_id = 9 and Team_Bowling = 2)

########## Finally extracting the Young Highest Scorer and Yound Highest Wicket Taker who are not in RCB team as of now

select Player_name, age, wkts_take, Tot_run from Final_View
where Player_id not in (select * from Batsman_Already_in_RCB)
and Player_id not in (select * from Bowler_Already_in_RCB)
order by WKts_Take desc, Tot_Run desc;


--------- Subjective 3)	What are some of parameters that should be focused while selecting the players
########### High Strike Rate Batsmen not playing for RCB
with Striker_View as
(select
	Striker,
    round((sum(Runs_Scored) / count(Runs_Scored)*100),2) as "Strike_rate"
from ball_by_ball_with_season
where Team_Batting != 2
group by 1
having count(Runs_Scored) > 100
and Strike_rate > 140)

select
	p.Player_Name,
	a.Strike_rate
from player as p
join Striker_View as a
on p.Player_Id = a.Striker
order by a.Strike_Rate desc;

########### Highest Wicket Takers who not playing for RCB

with Bowler_View as
(select
	Bowler,
    count(Player_out) as "Wickets"
from ball_by_ball_with_season
where Team_Bowling != 2
and Player_out != 0
group by 1
having count(Player_out) > 100)

select
	p.Player_Name,
	a.Wickets
from player as p
join Bowler_View as a
on p.Player_Id = a.Bowler
order by a.Wickets desc;



--------- Subjective 4) Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)


########## Calculating Tot_RUns Scored

with Runs_Scored as
(select Striker, sum(Runs_Scored) as Tot_Runs
from ball_by_ball_with_season
group by Striker),

########## Calcuating Total Wicktes taken

Wickets_Taken as
(select Bowler, count(player_out) as Wkts_taken
from ball_by_ball_with_season
where player_out != 0
group by Bowler),

########## Finding the Player name and who has scored more than 800 runs

Best_Batsman as
(select
	a.Player_Id,
    a.Player_Name,
    coalesce(r.Tot_Runs,0) as "Tot_Run"
from player as a

left join Runs_Scored as r
on a.Player_Id = r.Striker
where r.Tot_Runs > 800),

########## Finding the Player name and who has taken more than 50 wkts

Best_Bowler as
(select
	a.Player_Id,
    a.Player_Name,
    coalesce(w.Wkts_taken,0) as "Wkts_Take"
from player as a

left join Wickets_Taken as w
on a.Player_Id = w.Bowler
where w.Wkts_taken > 50),

########## Joining both the batsman and bowler in a single table

Final_View as(
SELECT
	s.Player_id,
    s.Player_Name,
    COALESCE(s.Wkts_Take, 0) AS Wkts_Take,
    COALESCE(t.Tot_Run, 0) AS Tot_Run
FROM 
    Best_Bowler s
LEFT JOIN 
    Best_Batsman t
ON 
    s.Player_Id = t.Player_Id

UNION

SELECT 
	t.Player_id,
    t.Player_Name,
    COALESCE(s.Wkts_Take, 0) AS Wkts_Take,
    COALESCE(t.Tot_Run, 0) AS Tot_Run
FROM 
    Best_Bowler s
RIGHT JOIN 
    Best_Batsman t
ON 
    s.Player_Id = t.Player_Id),
    

########## Finding Batsman who are already in RCB

Batsman_Already_in_RCB as
(select Striker from ball_by_ball_with_season
where Season_id = 9 and Team_Batting = 2),

########## Finding Bwoler who are already in RCB

Bowler_Already_in_RCB as
(select Bowler from ball_by_ball_with_season
where Season_id = 9 and Team_Bowling = 2)

########## Finally extracting the Good All-Rounders who are not in RCB team as of now

select Player_name, wkts_take, Tot_run from Final_View
where Player_id not in (select * from Batsman_Already_in_RCB)
and Player_id not in (select * from Bowler_Already_in_RCB)
and wkts_take != 0
and Tot_run != 0
order by WKts_Take desc, Tot_Run desc;


-------------- Subjective 5) Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualisation)

###### Finding the batsman wise matches won
with Striker_View as
(select
	Striker,
    count(distinct Match_id) as Matches_Won
from ball_by_ball_with_season
where Match_Winner = 2
and Team_batting = 2
group by Striker),

###### Finding the bowler wise matches won

Bowler_View as
(select
	Bowler,
    count(distinct Match_id) as Matches_Won
from ball_by_ball_with_season
where Match_Winner = 2
and Team_bowling = 2
group by Bowler),

###### Brought Batsman and Bowler under one table

My_Final_View as
(select * from Striker_View
union
select * from Bowler_View)

###### Extracted the Player Name and players who have won more than 15 matches

select
    p.Player_name,
    a.Matches_Won
from My_Final_View as a
left join Player as p
on a.Striker = p.Player_id
where a.Matches_Won > 15
order by a.Matches_Won desc;


------------- Subjective 6.	What would you suggest to RCB before going to mega auction? 

###### Young Talented Players

with All_Players as
(select Striker as "Player_Id",count(distinct Match_id) as Matches_Played 
from ball_by_ball_with_season
where Team_batting !=  2
group by 1

union
select bowler as "Player_Id", count(distinct Match_id) as Matches_Played 
from ball_by_ball_with_season
where Team_Bowling != 2
group by 1)

select 
	p.Player_name,
    a.Matches_played
from All_Players as a
join player as p
on a.Player_Id = p.Player_Id
where timestampdiff(year,p.DOB,"2017-01-01") <= 28
and Matches_played > 80


------------- Subjective 8)	Analyze the impact of home ground advantage on team performance and identify strategies to maximize this advantage for RCB.
########### Calculating Home Win% for RCB

with Tot_Matches as
(select count(distinct Match_id)
from matches
where Venue_id = 1
and (Team_1 = 2 or Team_2 = 2)),

Won_Matches as
(select count(distinct Match_id)
from matches
where Venue_id = 1
and Match_Winner = 2
and (Team_1 = 2 or Team_2 = 2))

select round(((select * from Won_Matches) / (select * from Tot_Matches)*100),2) as Home_Win_Percent;

########### Now calculating the cases wherein Match Winner and Toss Winner both are same

with Tot_Matches as
(select count(distinct Match_id)
from matches
where Venue_id = 1
and (Team_1 = 2 or Team_2 = 2)),

Toss_Winner as
(select count(distinct Match_id)
from matches
where Venue_id = 1
and Match_Winner = Toss_Winner)

select round(((select * from Toss_Winner) / (select * from Tot_Matches)*100),2) as Toss_Win_Match_Win_percent;

------------ Subjective 7.	What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies

with My_View as
(select
	distinct Team_Batting,
    Match_id
from ball_by_ball_with_season
where Team_Batting = Match_Winner
group by 1, match_id
having sum(Runs_Scored) > 200)

select
	b.Team_name,
    count(a.Match_id) as "Matches_Won"
from My_View as a
join team as b
on a.Team_Batting = b.Team_id
group by a.Team_Batting
order by Matches_Won desc


------------ Subjective 9)	Come up with a visual and analytical analysis with the RCB past seasons performance and potential reasons for them not winning a trophy.
###### Calculating the percentage how many times RCB has lost Chasing

with Tot_Matches as
(select count(distinct match_id) from matches
where Match_Winner != 2
and (Team_1 = 2 or Team_2 = 2)),

Lost_Chasing as
(select count(distinct match_id) from matches
where Match_Winner != 2
and Win_Type = 1
and (Team_1 = 2 or Team_2 = 2))

select (select * from Lost_Chasing) / (select * from Tot_Matches) *100 as Lost_Chasing_percent;
	
###### Now Calculating the percentage how many times RCB has lost Bating First
with Tot_Matches as
(select count(distinct match_id) from matches
where Match_Winner != 2
and (Team_1 = 2 or Team_2 = 2)),

Lost_Batting_First as
(select count(distinct match_id) from matches
where Match_Winner != 2
and Win_Type = 2
and (Team_1 = 2 or Team_2 = 2))

select (select * from Lost_Batting_First) / (select * from Tot_Matches) *100 as Lost_Batting_First_percent;

####### RCBs year over year Records
select * from matches;

with Total_Matches as
(select Season_id, count(distinct Match_id) as Tot_matches from matches
where Team_1 = 2 or Team_2 = 2
group by Season_id),

Won_Matches as
(select Season_id, count(distinct Match_id) as Won_matches from matches
where Match_Winner= 2
and (Team_1 = 2 or Team_2 = 2)
group by Season_id),

Lost_Matches as
(select Season_id, count(distinct Match_id) as Lost_matches from matches
where Match_Winner != 2
and (Team_1 = 2 or Team_2 = 2)
group by Season_id)

select t.Season_id, t.Tot_matches, w.Won_matches, l.Lost_matches,
round((w.Won_matches / t.Tot_matches) *100,2) as "Win%"
from Total_Matches t
left join Won_Matches w
on t.Season_id = w.Season_id

left join Lost_Matches l
on t.Season_id = l.Season_id;
