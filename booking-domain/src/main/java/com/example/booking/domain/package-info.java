/**
 * Domain layer of the booking platform: the business model and its rules, organised by feature.
 *
 * <p>This module must stay free of Spring, the Servlet API, Jackson and other framework or web
 * concerns. The Maven Enforcer rules in {@code booking-domain/pom.xml} fail the build if such a
 * dependency is added.
 */
package com.example.booking.domain;
