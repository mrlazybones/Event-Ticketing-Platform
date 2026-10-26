/**
 * Application layer of the booking platform: use-case services that coordinate the domain model,
 * define transaction boundaries and talk to persistence, organised by feature.
 *
 * <p>This module must not depend on the web layer (Spring MVC, the Servlet API or embedded
 * Tomcat); the Maven Enforcer rules in {@code booking-service/pom.xml} fail the build if it does.
 * Controllers in {@code booking-api} call these services, never the other way round.
 */
package com.example.booking.service;
