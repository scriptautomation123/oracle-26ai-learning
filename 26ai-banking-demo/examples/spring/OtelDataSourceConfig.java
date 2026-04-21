package com.oracle.nudges.examples.spring;

import javax.sql.DataSource;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.instrumentation.jdbc.datasource.JdbcTelemetry;

@Configuration
public class OtelDataSourceConfig {

    @Bean
    @Primary
    DataSource otelDataSource(DataSource raw, OpenTelemetry otel) {
        return JdbcTelemetry.create(otel).wrap(raw);
    }
}
