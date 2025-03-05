pluginManagement {
    val flutterSdkPath by extra {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk") ?: error("flutter.sdk not set in local.properties")
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
}

include(":app")

val flutterProjectRoot = rootProject.projectDir.parentFile.toPath()

val plugins = java.util.Properties().apply {
    val pluginsFile = File(flutterProjectRoot.toFile(), ".flutter-plugins")
    if (pluginsFile.exists()) {
        pluginsFile.inputStream().use { load(it) }
    }
}

plugins.forEach { (name, path) ->
    name as String; path as String
    val pluginDirectory = flutterProjectRoot.resolve(path).resolve("android").toFile()
    include(":$name")
    project(":$name").projectDir = pluginDirectory
}
