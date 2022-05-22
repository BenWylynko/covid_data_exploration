SELECT *
FROM dbo.covidDeaths
Where continent is not null
order by 1, 2;

SELECT * 
	FROM dbo.covidVaccinations$
		order by 3, 4;

SELECT Location, date, total_cases, new_cases, total_deaths, population
From covidDeaths
order by 1, 2;

-- BY LOCATION (COUNTRY)

-- what fraction of people with cases died, by country?
SELECT Location, date, total_cases, total_deaths, (total_deaths / total_cases)*100 as DeathPercentage
From covidDeaths
where location like 'canada'
And continent is not null
order by 1, 2;

-- what fraction of population infected with covid, by country?
SELECT Location, date, total_cases, population, (total_cases / population)*100 as infectedPercentage
From covidDeaths
Where continent is not null
order by 1, 2;

-- what countries have the highest infection rates relative to population?
SELECT Location, population, MAX(total_cases) as GreatestInfectionCount, MAX((total_cases / population)*100) as infectedPercentage
From covidDeaths
--where location like 'canada'
Group by Location, population
order by infectedPercentage desc;
-- Faeroe Islands (70%), Andorra, Cyprus

-- which countries have the highest death count per population?
SELECT Location, population, MAX((total_deaths / population)*100) as maxDeathRate
From covidDeaths
Where continent is not Null
Group by Location, population
order by maxDeathRate desc;
--Peru, Bulgaria

-- what percent of population has received at least 1 vaccine?
-- try doing this both with total_vaccinations and with a rolling count
--using total vaccinations
SELECT dea.location, dea.population, MAX(convert(bigint, vac.total_vaccinations)) / dea.population * 100 as partial_vaccinated_percent
from covidDeaths dea
Join covidVaccinations$ vac
	On dea.location = vac.location and dea.date = vac.date
Group by dea.location, dea.population
Order by 1, 2;

-- using a rolling count (with a CTE to get vaccinations / population)
With VaxCount (location, population, date, new_vaccinations, vaxRollingCount) as (
	SELECT dea.location, dea.population, dea.date, vac.new_vaccinations, SUM(convert(int, vac.new_vaccinations)) over (Partition by dea.location order by dea.location, dea.date) as vaxRollingCount
	from covidDeaths dea
	Join covidVaccinations$ vac
		On dea.location = vac.location and dea.date = vac.date
	where dea.location like 'Canada'
)

SELECT *, vaxRollingCount / population * 100
From VaxCount;

-- using a rolling count with a temp table
Drop Table if exists #PercentPopVaccinated
Create Table #PercentPopVaccinated
(
	Location nvarchar(255), 
	Date datetime, 
	Population numeric, 
	new_vaccinations numeric, 
	vaxRollingCount numeric
)

Insert into #PercentPopVaccinated
SELECT dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(convert(int, vac.new_vaccinations)) over (Partition by dea.location order by dea.location, dea.date) as vaxRollingCount
from covidDeaths dea
Join covidVaccinations$ vac
	On dea.location = vac.location and dea.date = vac.date
where dea.location like 'Canada'

SELECT *, vaxRollingCount / population * 100
From #PercentPopVaccinated;



-- How many weekly ICU admissions per population, by week? (averaged over the week, I assume)
SET DATEFIRST 4 -- Thursday
SELECT location, population, DATEPART(week, date), AVG(convert(int, weekly_icu_admissions))
FROM covidDeaths
Where weekly_icu_admissions is not Null
-- and location like 'Canada'
Group by location, population, DATEPART(week, date)
Order by 1, 2;

-- how many boosters per population?
--If exists(select * From sys.views where name = 'boostersPercent')
--	Drop view boostersPercent;

go
Create view boostersPercent as
SELECT vac.location, vac.population, vac.date, dea.weekly_icu_admissions, MAX(Convert(bigint, vac.total_boosters)) over (Partition by vac.location order by vac.location) as maxBoosters
FROM covidVaccinations$ vac
Join covidDeaths dea
	On dea.location = vac.location and dea.date = vac.date
	Where dea.weekly_icu_admissions is not Null;

Select * From boostersPercent
Where location like 'Chile';

SELECT location, population, DATEPART(week, date), AVG(convert(float, weekly_icu_admissions)) / (AVG(maxBoosters) / population) as ICUAdmisPerBoosterFraction
From boostersPercent
Where location like 'Chile'
Group by location, population, DATEPART(week, date)
Order by 1, 2;

-- how many new deaths per month?
With monthlyDeaths as (
	SELECT location, population, DATEPART(year, date) as year, DATEPART(month, date) as month, SUM(CONVERT(int, new_deaths)) as newDeathsPerMonth
	From covidDeaths
	Where location like 'Canada'
	Group by location, population, DATEPART(year, date), DATEPART(month, date)
)

Select * from monthlyDeaths
Order by 1, 2;

-- How many new cases per population density, per month?
SELECT dea.location, dea.population, vac.population_density, DATEPART(year, dea.date) as year, DATEPART(month, dea.date) as month, SUM(CONVERT(int, dea.new_cases)) / AVG(vac.population_density) as newCasesPerDensity
From covidDeaths dea
Join covidVaccinations$ vac
	On dea.location = vac.location and dea.date = vac.date
-- Where location like 'Canada'
Group by dea.location, dea.population, vac.population_density, DATEPART(year, dea.date), DATEPART(month, dea.date);


-- BY CONTINENT

-- what about the continents with highest death count per population?
SELECT continent, MAX((total_deaths / population)*100) as maxDeathRate
From covidDeaths
Where continent is not Null
Group by continent
order by maxDeathRate desc;
-- South America the worst (0.63%), Oceania the best


-- GLOBALLY
 --total cases, total deaths, death percentage overall
SELECT SUM(new_cases), SUM(cast(new_deaths as int)) as total_deaths, (SUM(cast(new_deaths as int)) / SUM(new_cases))*100 as overallDeathRate
FROM covidDeaths
where continent is not null;

-- how many vaccines have been given, relative to population?
SELECT dea.location, dea.population, SUM(cast(vac.new_vaccinations as bigint)) as total_vaccinations, SUM(cast(vac.new_vaccinations as bigint)) / dea.population as vacs_per_pop
from covidDeaths dea
Join covidVaccinations$ vac
	On dea.location = vac.location and dea.date = vac.date
Where dea.continent is not Null 
	and vac.new_vaccinations is not Null
Group by dea.location, dea.population
order by 1, 2



