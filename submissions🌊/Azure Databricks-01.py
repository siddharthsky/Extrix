# Import necessary libraries
from pyspark.sql import SparkSession

# Create a SparkSession
spark = SparkSession.builder.appName("MovielensAnalysis").getOrCreate()

# Load the dataset
ratings_df = spark.read.format("csv").option("header", True).load("dbfs:/mnt/<datalake-name>/<path-to-dataset>/ratings.csv")
movies_df = spark.read.format("csv").option("header", True).load("dbfs:/mnt/<datalake-name>/<path-to-dataset>/movies.csv")
links_df = spark.read.format("csv").option("header", True).load("dbfs:/mnt/<datalake-name>/<path-to-dataset>/links.csv")
tags_df = spark.read.format("csv").option("header", True).load("dbfs:/mnt/<datalake-name>/<path-to-dataset>/tags.csv")

# View the schema of the ratings dataframe
ratings_df.printSchema()

# Register the dataframes as tables to use Spark SQL
ratings_df.createOrReplaceTempView("ratings")
movies_df.createOrReplaceTempView("movies")
links_df.createOrReplaceTempView("links")
tags_df.createOrReplaceTempView("tags")

# Example query: Find the top 10 rated movies with at least 100 ratings
query = """
SELECT movies.title, AVG(ratings.rating) AS avg_rating, COUNT(ratings.rating) AS num_ratings
FROM movies
JOIN ratings ON movies.movieId = ratings.movieId
GROUP BY movies.movieId, movies.title
HAVING COUNT(ratings.rating) >= 100
ORDER BY AVG(ratings.rating) DESC
LIMIT 10
"""

# Execute the query
top_rated_movies = spark.sql(query)

# Show the results
top_rated_movies.show()
