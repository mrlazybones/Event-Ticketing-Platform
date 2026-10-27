package com.example.booking.api.health;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.example.booking.service.common.DatabaseConnectivityChecker;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/** Web slice for readiness. The database is replaced so this test never opens a connection. */
@WebMvcTest(ReadinessController.class)
class ReadinessControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private DatabaseConnectivityChecker database;

    @Test
    void returnsUpWhenTheDatabaseIsReady() throws Exception {
        when(database.isReady()).thenReturn(true);

        mockMvc.perform(get("/api/v1/health/readiness"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(content().json("{\"status\":\"UP\"}"));
    }

    @Test
    void returnsDownWithoutInternalDetails() throws Exception {
        when(database.isReady()).thenReturn(false);

        mockMvc.perform(get("/api/v1/health/readiness"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(content().json("{\"status\":\"DOWN\"}"))
                .andExpect(jsonPath("$.error").doesNotExist())
                .andExpect(jsonPath("$.password").doesNotExist());
    }

    @Test
    void rejectsNonGetRequests() throws Exception {
        mockMvc.perform(post("/api/v1/health/readiness")).andExpect(status().isMethodNotAllowed());
    }
}
