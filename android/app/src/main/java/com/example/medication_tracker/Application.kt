package com.example.medication_tracker

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class Application : Application() {
    override fun onCreate() {
        super.onCreate()
        
        // Инициализируем Flutter engine для фоновых задач
        val flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        
        // Сохраняем engine для повторного использования
        FlutterEngineCache.getInstance().put("background_engine", flutterEngine)
    }
}