--Final Work (SQL)

-- 1. Which cities have more than one airport?
select city, count (airport_name) 
from airports 
group by city 
having count (airport_name) > 1;

--2. Which airports have flights operated by the aircraft with the longest flight distance?
select distinct airport_name as "airport"
from airports
inner join flights on airports.airport_code = flights.arrival_airport
inner join aircrafts on flights.aircraft_code = aircrafts.aircraft_code
where aircrafts.range = (select max(range) from aircrafts);

-- 3. Display 10 flights with the longest flight delay
select flight_id, scheduled_departure, actual_departure, (actual_departure - scheduled_departure) as time
from flights where actual_departure is not null
order by time desc
limit 10;

--4. Were there any bookings that did not receive boarding passes?
select count(bookings.book_ref)
from bookings
full outer join tickets on bookings.book_ref = tickets.book_ref
full outer join boarding_passes on boarding_passes.ticket_no = tickets.ticket_no
where boarding_passes.boarding_no is null;


--Find the number of empty seats for each flight, their % ratio to the total number of seats on the plane.
-- Add a column with a cumulative total - the total accumulation of the number of passengers taken out from each airport for each day. 
-- Those this column should reflect the cumulative amount - how many people have already departed from this airport on this or earlier flights during the day.

select
	f.flight_id as "flight", 
	f.aircraft_code as "aircraft code", 
	f.departure_airport as "departure airport", 
	date(f.actual_departure) as "date actual departure",
	(s.count_seats - bp.count_bp) as "free seats",
	round(((s.count_seats - bp.count_bp) * 100. / s.count_seats), 2) as "%",
	sum(bp.count_bp) over (partition by date(f.actual_departure),
	f.departure_airport
order by
	f.actual_departure) as "actual departure",
	bp.count_bp as "seats"
from
	flights f
left join (
	select
		bp.flight_id,
		count(bp.seat_no) as count_bp
	from
		boarding_passes bp
	group by
		bp.flight_id
	order by
		bp.flight_id) as bp on
	bp.flight_id = f.flight_id
left join (
	select
		s.aircraft_code,
		count(*) as count_seats
	from
		seats s
	group by
		s.aircraft_code) as s on
	f.aircraft_code = s.aircraft_code
where
	f.actual_departure is not null
	and bp.count_bp is not null
order by
	date(f.actual_departure)

-- 6. Find the percentage of flights by aircraft type of the total.
select aircrafts.model as "model aircraft", aircrafts.aircraft_code, 
round((count(flights.flight_id)::numeric)*100 / (select count(flights.flight_id) from flights)::numeric, 2) as "%"
from aircrafts
join flights on aircrafts.aircraft_code = flights.aircraft_code
group by aircrafts.aircraft_code
order by "model aircraft" desc;

-- 7. Were there any cities that you can get to in business class cheaper than in economy class as part of the flight?

 with econom as
	(select flight_id, max(amount)
	from ticket_flights
	where fare_conditions = 'Economy'
	group by flight_id),
business as
	(select flight_id, min(amount) as min
	from ticket_flights
	where fare_conditions = 'Business' 
	group by flight_id)
select e.flight_id, min, max, a1.city, a2.city
from econom e
join business b on e.flight_id = b.flight_id
left join flights f on e.flight_id = f.flight_id and b.flight_id = f.flight_id
left join airports a1 on a1.airport_code = f.arrival_airport
left join airports a2 on a2.airport_code = f.departure_airport
where max > min;

select fv.departure_city, fv.arrival_city
from (
	select flight_id
	from ticket_flights
	group by flight_id
	having max(amount) filter (where fare_conditions = 'Economy') > min(amount) filter (where fare_conditions = 'Business')) t 
join flights_v fv on fv.flight_id = t.flight_id

-- 8. Between which cities there are no direct flights?
create view route as 
	select distinct a.city as departure_city , b.city as arrival_city, a.city||'-'||b.city as route 
	from airports as a, (select city from airports) as b
	where a.city != b.city
	order by route
	
create view direct_flight as 
	select distinct a.city as departure_city, aa.city as arrival_city, a.city||'-'|| aa.city as route  
	from flights as f
	inner join airports as a on f.departure_airport=a.airport_code
	inner join airports as aa on f.arrival_airport=aa.airport_code
	order by route
	
select r.* 
from route as r
except 
select df.* 
from direct_flight as df

-- 9. Calculate the distance between airports connected by direct flights, compare with the allowable maximum flight distance in aircraft serving these flights
select departure_airport, a1.latitude as x, arrival_airport, a2.longitude as y, 
(acos(sin(radians(a1.latitude))*sin(radians(a2.latitude)) +cos(radians(a1.latitude))*
cos(radians(a2.latitude))*cos(radians(a1.longitude - a2.longitude)))*6371)::integer as "??????????", range
from 
	(select distinct departure_airport, arrival_airport, aircraft_code 
	from flights) as foo
join airports a1 on foo.departure_airport = a1.airport_code
join airports a2 on foo.arrival_airport = a2.airport_code
join aircrafts on aircrafts.aircraft_code = foo.aircraft_code
order by arrival_airport