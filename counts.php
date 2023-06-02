<?php

$hostname = '%MYSQL_HOSTNAME%';  
$username = '%MYSQL_USERNAME%';
$password = '%MYSQL_PASSWORD%';
$database = '%MYSQL_DATABASE%';
$table = 'visits';


$connection = mysqli_connect($hostname, $username, $password, $database);
if (!$connection) {
    die('Failed to connect to MySQL: ' . mysqli_connect_error());
}

// Check if table is empty
$query = "SELECT * FROM $table";
$result = mysqli_query($connection, $query);
$row_count = mysqli_num_rows($result);

if ($row_count == 0) {
    // Table is empty, insert initial count value
    $initialCount = 1;
    $query = "INSERT INTO $table (count) VALUES ($initialCount)";
    mysqli_query($connection, $query);
} else {
    // Retrieve current count from database
    $query = "SELECT count FROM $table WHERE id = 1";
    $result = mysqli_query($connection, $query);
    $row = mysqli_fetch_assoc($result);
    $count = $row ? $row['count'] : 0;

    // Increase the visit count
    $count++;
    $query = "UPDATE $table SET count = $count WHERE id = 1";
    mysqli_query($connection, $query);
}
// Output the visit count
echo "Total visits: $count";

// Close the database connection
mysqli_close($connection);
?>





