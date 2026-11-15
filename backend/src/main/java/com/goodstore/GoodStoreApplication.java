package com.goodstore;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.view.RedirectView;

@SpringBootApplication
@RestController
public class GoodStoreApplication {
    public static void main(String[] args) {
        SpringApplication.run(GoodStoreApplication.class, args);
    }

    @GetMapping("/api/health")
    public String health() {
        return "Good Store server is running";
    }

    @GetMapping("/")
    public RedirectView home() { return new RedirectView("/user/index.html"); }
}
