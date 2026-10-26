package com.example.booking;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Entry point of the Event Ticketing and Booking Platform.
 *
 * <p>It lives in the root package so that component scanning covers every module:
 * {@code com.example.booking.api}, {@code com.example.booking.service} and
 * {@code com.example.booking.domain}.
 */
@SpringBootApplication
public class BookingApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(BookingApiApplication.class, args);
    }
}
