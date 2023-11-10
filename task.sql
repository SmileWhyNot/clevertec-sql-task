-- Вывести к каждому самолету класс обслуживания и количество мест этого класса
SET
search_path = bookings, public;

-- SELECT aircrafts.model AS model, seats.fare_conditions AS cond, count(seats.seat_no) AS seats_count
-- FROM aircrafts
--          JOIN seats ON aircrafts.aircraft_code = seats.aircraft_code
-- GROUP BY model, cond
-- ORDER BY model;

SELECT aircrafts_data.aircraft_code AS код_самолета, seats.fare_conditions AS класс_обслуживания, count(seats.seat_no) AS количество_мест
FROM aircrafts_data
         JOIN seats ON aircrafts_data.aircraft_code = seats.aircraft_code
GROUP BY код_самолета, класс_обслуживания
ORDER BY код_самолета;

-- Найти 3 самых вместительных самолета (модель + кол-во мест)

-- SET
-- search_path = bookings, public;
-- SELECT aircrafts.model AS model, count(seats.seat_no) AS seats_count
-- FROM aircrafts
--          JOIN seats ON aircrafts.aircraft_code = seats.aircraft_code
-- GROUP BY model
-- ORDER BY seats_count DESC LIMIT 3;

SET search_path = bookings, public;
SELECT aircrafts_data.aircraft_code AS код_самолета, aircrafts_data.model->>'ru' AS модель, count(seats.seat_no) AS количество_мест
FROM aircrafts_data
         JOIN seats ON aircrafts_data.aircraft_code = seats.aircraft_code
GROUP BY код_самолета
ORDER BY количество_мест DESC
LIMIT 3;

-- Вывести код, модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам

-- SET
-- search_path = bookings, public;
-- SELECT aircrafts.aircraft_code as code, aircrafts.model AS model, count(seats.seat_no) AS seats_count
-- FROM aircrafts
--          JOIN seats ON aircrafts.aircraft_code = seats.aircraft_code
-- WHERE seats.fare_conditions IN ('Business', 'Comfort')
-- GROUP BY model, code
-- ORDER BY seats_count;

SELECT aircrafts_data.aircraft_code as code, aircrafts_data.model->>'ru' AS model, seats.seat_no AS seats
FROM aircrafts_data
         JOIN seats ON aircrafts_data.aircraft_code = seats.aircraft_code
WHERE aircrafts_data.model->>'ru' = 'Аэробус A321-200' AND
        seats.fare_conditions IN ('Comfort', 'Business')
ORDER BY seats;

-- Вывести города в которых больше 1 аэропорта ( код аэропорта, аэропорт, город)

-- SET
-- search_path = bookings, public;
-- WITH cities AS (SELECT airports.city AS city
--                 FROM airports
--                 GROUP BY city
--                 HAVING count(city) > 1)
-- SELECT airport_code, airport_name, city
-- FROM airports
-- WHERE city IN (SELECT city from cities);

SELECT a.city->>'ru' AS city, a.airport_code AS airport_code, a.airport_name->>'ru' AS airport_name
FROM airports_data a
    JOIN airports_data a2 ON a.city = a2.city
GROUP BY a.city, a.airport_code
HAVING COUNT(a.airport_code) > 1;


-- Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация

SET
search_path = bookings, public;
-- WITH cities AS (SELECT city, airport_code
--                 FROM airports
--                 WHERE city = 'Екатеринбург'
--                    OR city = 'Москва'
--                 GROUP BY city, airport_code)
-- SELECT flights.*
-- FROM flights
--          JOIN airports ON flights.departure_airport = airports.airport_code
-- WHERE departure_airport IN (select airport_code from cities where city LIKE 'Екатеринбург')
--   AND arrival_airport IN (select airport_code from cities where city LIKE 'Москва')
--   AND status IN ('Scheduled', 'On Time', 'Delayed')
-- ORDER BY scheduled_departure LIMIT 1;

WITH cities AS (SELECT city, airport_code
                FROM airports_data
                WHERE city ->> 'ru' = 'Екатеринбург'
                   OR city ->> 'ru' = 'Москва'
                GROUP BY city, airport_code)
SELECT flights.*
FROM flights
         JOIN airports_data ON flights.departure_airport = airports_data.airport_code
WHERE departure_airport IN (select airport_code from cities where city ->> 'ru' LIKE 'Екатеринбург')
  AND arrival_airport IN (select airport_code from cities where city ->> 'ru' LIKE 'Москва')
  AND status IN ('Scheduled', 'On Time', 'Delayed')
ORDER BY scheduled_departure LIMIT 1;

-- Вывести самый дешевый и дорогой билет и стоимость ( в одном результирующем ответе)
(SELECT tickets.ticket_no, ticket_flights.amount
 FROM tickets
          JOIN ticket_flights ON tickets.ticket_no = ticket_flights.ticket_no
 ORDER BY ticket_flights.amount LIMIT 1)

UNION ALL

(SELECT tickets.ticket_no, ticket_flights.amount
 FROM tickets
          JOIN ticket_flights ON tickets.ticket_no = ticket_flights.ticket_no
 ORDER BY ticket_flights.amount DESC LIMIT 1);

    /*
    ВОЗМОЖНО я замудрил тут, поэтому ниже несколько решений. В таблице ticket_flights может быть
    несколько билетов с одинаковым ticket_no, так как одно бронирование = один билет = один или много рейсов
    ПОЭТОМУ чтобы искать самый дешевый и дорогой билет надо сначала общую цену билета посчитать, учитывая все рейсы
    одного билета. Если так, то решение ниже
    */
WITH ticket_total_amount AS (SELECT tickets.ticket_no,
                                    SUM(ticket_flights.amount) AS total_amount
                             FROM tickets
                                      JOIN
                                  ticket_flights ON tickets.ticket_no = ticket_flights.ticket_no
                             GROUP BY tickets.ticket_no)
SELECT min_ticket.ticket_no    AS Num_min_ticket,
       min_ticket.total_amount AS min_amount,
       max_ticket.ticket_no    AS Num_max_ticket,
       max_ticket.total_amount AS max_amount
FROM (SELECT ticket_no,
             total_amount
      FROM ticket_total_amount
      WHERE total_amount = (SELECT MIN(total_amount) FROM ticket_total_amount)) AS min_ticket,
     (SELECT ticket_no,
             total_amount
      FROM ticket_total_amount
      WHERE total_amount = (SELECT MAX(total_amount) FROM ticket_total_amount)) AS max_ticket;
    /*
    Если это не важно, то ниже два других решения
    */
    /* Вариант где один минимальный и один максимальный */
SELECT min_ticket.ticket_no         AS number_min_ticket,
       min_ticket.min_ticket_amount AS min_amount,
       max_ticket.ticket_no         AS number_max_ticket,
       max_ticket.max_ticket_amount AS max_amount
FROM (SELECT tickets.ticket_no, ticket_flights.amount AS min_ticket_amount
      FROM tickets
               JOIN ticket_flights ON tickets.ticket_no = ticket_flights.ticket_no
      ORDER BY amount LIMIT 1) AS min_ticket,
     (SELECT tickets.ticket_no, ticket_flights.amount AS max_ticket_amount
      FROM tickets
               JOIN ticket_flights ON tickets.ticket_no = ticket_flights.ticket_no
      ORDER BY amount DESC LIMIT 1) AS max_ticket;

        /* Вариант где все минимальные и все максимальные */
WITH tickets_amount AS (SELECT tickets.ticket_no, ticket_flights.amount
                        FROM tickets
                                 JOIN ticket_flights ON tickets.ticket_no = ticket_flights.ticket_no),
     min_ticket AS (SELECT ticket_no, amount
                    FROM tickets_amount
                    WHERE amount = (SELECT MIN(amount) FROM tickets_amount)),
     max_ticket AS (SELECT ticket_no, amount
                    FROM tickets_amount
                    WHERE amount = (SELECT MAX(amount) FROM tickets_amount))
SELECT min_ticket.ticket_no AS Num_min_ticket,
       min_ticket.amount    AS min_amount,
       max_ticket.ticket_no AS Num_max_ticket,
       max_ticket.amount    AS max_amount
FROM min_ticket,
     max_ticket;


-- Вывести информацию о вылете с наибольшей суммарной стоимостью билетов
SET
search_path = bookings, public;

WITH flight_total_amount AS (SELECT flights.flight_id,
                                    SUM(ticket_flights.amount) AS total_amount
                             FROM ticket_flights
                                      JOIN
                                  flights ON ticket_flights.flight_id = flights.flight_id
                             GROUP BY flights.flight_id)
SELECT flights.*,
       total_amount
FROM flights
         JOIN
     flight_total_amount ON flights.flight_id = flight_total_amount.flight_id
WHERE flight_total_amount.total_amount = (SELECT MAX(total_amount) FROM flight_total_amount);


-- Найти модель самолета, принесшую наибольшую прибыль (наибольшая суммарная стоимость билетов). Вывести код модели, информацию о модели и общую стоимость

-- SET
-- search_path = bookings, public;
--
-- WITH flight_total_amount AS (SELECT flights.flight_id,
--                                     SUM(ticket_flights.amount) AS total_amount
--                              FROM ticket_flights
--                                       JOIN
--                                   flights ON ticket_flights.flight_id = flights.flight_id
--                              GROUP BY flights.flight_id)
-- SELECT aircrafts.aircraft_code, aircrafts.model, sum(total_amount) AS aircraft_amount
-- FROM flight_total_amount
--          JOIN flights ON flight_total_amount.flight_id = flights.flight_id
--          JOIN aircrafts ON flights.aircraft_code = aircrafts.aircraft_code
-- GROUP BY aircrafts.model, aircrafts.aircraft_code
-- ORDER BY aircraft_amount DESC LIMIT 1;

WITH flight_total_amount AS (
    SELECT flights.aircraft_code,
           SUM(ticket_flights.amount) AS total_amount
    FROM ticket_flights
             JOIN flights ON ticket_flights.flight_id = flights.flight_id
    GROUP BY flights.aircraft_code
),
     max_aircraft_amount AS (
         SELECT MAX(total_amount) AS max_amount
         FROM flight_total_amount
     )
SELECT aircrafts.aircraft_code, aircrafts.model, sum(flight_total_amount.total_amount) AS aircraft_amount
FROM flight_total_amount
         JOIN aircrafts ON flight_total_amount.aircraft_code = aircrafts.aircraft_code
         CROSS JOIN max_aircraft_amount
WHERE flight_total_amount.total_amount = max_aircraft_amount.max_amount
GROUP BY aircrafts.aircraft_code, aircrafts.model;


-- Найти самый частый аэропорт назначения для каждой модели самолета. Вывести количество вылетов, информацию о модели самолета, аэропорт назначения, город
WITH aircraft_airport_flights AS (SELECT aircrafts.aircraft_code,
                                         flights.arrival_airport,
                                         count(flights.arrival_airport) AS flights_count
                                  FROM aircrafts
                                           JOIN
                                       flights ON aircrafts.aircraft_code = flights.aircraft_code
                                  GROUP BY aircrafts.aircraft_code, flights.arrival_airport),
     max_flights_per_aircraft AS (SELECT aircraft_code,
                                         MAX(flights_count) AS max_flights_count
                                  FROM aircraft_airport_flights
                                  GROUP BY aircraft_code)
SELECT aaf.aircraft_code,
       aircrafts.model,
       aaf.arrival_airport,
       airports.city,
       aaf.flights_count
FROM aircraft_airport_flights AS aaf
         JOIN
     max_flights_per_aircraft AS mfa ON aaf.aircraft_code = mfa.aircraft_code
         JOIN
     aircrafts ON aaf.aircraft_code = aircrafts.aircraft_code
         JOIN
     airports ON aaf.arrival_airport = airports.airport_code
WHERE aaf.flights_count = mfa.max_flights_count;