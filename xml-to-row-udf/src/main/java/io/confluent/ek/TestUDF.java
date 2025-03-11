package io.confluent.ek;

import org.apache.flink.table.annotation.DataTypeHint;
import org.apache.flink.table.functions.ScalarFunction;
import org.apache.flink.types.Row;

import java.util.ArrayList;

public class TestUDF extends ScalarFunction {
    public static final String NAME = "test";

/*
            "ROW<name STRING, orResult ROW<flight_number STRING, carrier STRING, departure_timestamp BIGINT, origin STRING, destination STRING, passengers ARRAY<ROW<reference STRING, name STRING>>>>"
            "ROW<name STRING, orResult ROW<flight_number STRING, carrier STRING>>"
            "ROW<name STRING, passengers ARRAY<ROW<reference STRING, passenger_name STRING>>>"
            "ROW<name STRING, passengers ARRAY<STRING>>"

 */
    @DataTypeHint(
            "ROW<name STRING, passengers ARRAY<ROW<reference STRING, age INT>>>"
    )
    public Row eval(){
        return Row.of("no err123456", null);
    }

}