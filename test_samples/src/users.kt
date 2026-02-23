package com.example.demo

import kotlinx.co routines.*
import kotlinx.coroutines.flow.*

data class User(val id: Int, val name: String, val email: String)

sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Error(val message: String, val code: Int = 0) : ApiResult<Nothing>()
    object Loading : ApiResult<Nothing>()
}

class UserRepository {
    private val users = mutableListOf(
        User(1, "Alice", "alice@example.com"),
        User(2, "Bob", "bob@example.com"),
        User(3, "Charlie", "charlie@example.com"),
    )

    fun getUsers(): Flow<ApiResult<List<User>>> = flow {
        emit(ApiResult.Loading)
        delay(500)
        emit(ApiResult.Success(users.toList()))
    }

    suspend fun addUser(name: String, email: String): ApiResult<User> {
        delay(200)
        val user = User(id = users.size + 1, name = name, email = email)
        users.add(user)
        return ApiResult.Success(user)
    }

    fun searchUsers(query: String): List<User> {
        return users.filter {
            it.name.contains(query, ignoreCase = true) ||
            it.email.contains(query, ignoreCase = true)
        }
    }
}

fun main() = runBlocking {
    val repo = UserRepository()

    repo.getUsers().collect { result ->
        when (result) {
            is ApiResult.Loading -> println("Loading...")
            is ApiResult.Success -> println("Users: ${result.data}")
            is ApiResult.Error -> println("Error: ${result.message}")
        }
    }

    val newUser = repo.addUser("Diana", "diana@example.com")
    println("Added: $newUser")
    println("Search 'a': ${repo.searchUsers("a")}")
}
