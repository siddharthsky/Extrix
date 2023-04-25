#QUE - 01

# Import necessary libraries
from pyspark.sql import SparkSession

# Create a SparkSession
spark = SparkSession.builder.appName("MovielensAnalysis").getOrCreate()

# Load the dataset
ratings_df = spark.read.format("csv").option("header", True).load("dbfs:/mnt/hdfsx/db/ratings.csv")
movies_df = spark.read.format("csv").option("header", True).load("dbfs:/mnt/hdfsx/db/movies.csv")
links_df = spark.read.format("csv").option("header", True).load("dbfs:/mnt/hdfsx/db/links.csv")
tags_df = spark.read.format("csv").option("header", True).load("dbfs:/mnt/hdfsx/db/tags.csv")

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




------------------------------------------------------------
#QUE - 02

# Import required libraries
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, FloatType

# Set up a Spark session
spark = SparkSession.builder.appName("YelpAnalysis").getOrCreate()

# Define the schema for the Yelp reviews dataset
schema = StructType([
  StructField("business_id", StringType(), True),
  StructField("cool", IntegerType(), True),
  StructField("date", StringType(), True),
  StructField("funny", IntegerType(), True),
  StructField("review_id", StringType(), True),
  StructField("stars", IntegerType(), True),
  StructField("text", StringType(), True),
  StructField("useful", IntegerType(), True),
  StructField("user_id", StringType(), True)
])

# Read the Yelp reviews dataset in Parquet format
yelp_reviews = spark.read.schema(schema).parquet("/mnt/yelp-dataset/reviews.parquet")

# Print the schema and first few rows of the dataset
yelp_reviews.printSchema()
yelp_reviews.show(5)

# Perform some basic analysis on the dataset
# Get the total number of reviews
num_reviews = yelp_reviews.count()
print("Total number of reviews:", num_reviews)

# Get the average star rating
avg_stars = yelp_reviews.select(avg("stars")).collect()[0][0]
print("Average star rating:", avg_stars)

# Get the top 10 most reviewed businesses
top_businesses = yelp_reviews.groupBy("business_id").count().orderBy(desc("count")).limit(10)
print("Top 10 most reviewed businesses:")
top_businesses.show()

