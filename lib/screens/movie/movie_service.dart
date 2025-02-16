/// Gets movies for the current user (excluding forks)
Stream<List<Map<String, dynamic>>> getUserMovies() {
  return _firestoreService.getUserMovies();
}

/// Gets only forked movies for the current user
Stream<List<Map<String, dynamic>>> getUserForkedMovies() {
  return _firestoreService.getUserForkedMovies();
} 