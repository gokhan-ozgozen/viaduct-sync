plugins {
    id("conventions.java")
}

description = "Java Tenant API Interfaces"

dependencies {
    compileOnly(libs.jspecify)

    testImplementation(libs.assertj.core)
}
