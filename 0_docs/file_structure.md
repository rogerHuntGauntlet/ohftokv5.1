# OHFtok Application File Structure

## Core Structure
```
lib/
├── main.dart
├── config/
│   ├── constants.dart
│   ├── routes.dart
│   └── theme/
│       ├── app_theme.dart
│       └── theme_constants.dart
│
├── models/
│   ├── user/
│   │   └── user.dart
│   ├── achievement/
│   │   └── achievement.dart
│   ├── video/
│   │   └── video.dart
│   ├── movie/
│   │   ├── movie_idea.dart
│   │   └── movie_scene.dart
│   └── notification/
│       └── notification.dart
│
├── screens/
│   ├── auth/
│   │   ├── auth_wrapper.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── forgot_password_screen.dart
│   │
│   ├── onboarding/
│   │   ├── onboarding_screen.dart
│   │   └── components/
│   │       ├── interest_selection.dart
│   │       └── onboarding_page.dart
│   │
│   ├── home/
│   │   ├── home_page.dart
│   │   └── components/
│   │       ├── video_feed_item.dart
│   │       └── bottom_nav_bar.dart
│   │
│   ├── movie/
│   │   ├── movie_scenes_screen.dart
│   │   ├── scene_recording_screen.dart
│   │   └── components/
│   │       ├── scene_card.dart
│   │       └── recording_controls.dart
│   │
│   └── profile/
│       ├── profile_screen.dart
│       └── components/
│           ├── profile_header.dart
│           └── achievement_list.dart
│
├── services/
│   ├── auth/
│   │   └── auth_service.dart
│   ├── theme/
│   │   └── theme_service.dart
│   ├── achievements/
│   │   └── achievement_service.dart
│   ├── video/
│   │   ├── video_service.dart
│   │   ├── video_processing_service.dart
│   │   └── video_cache_service.dart
│   ├── social/
│   │   ├── social_service.dart
│   │   └── notification_service.dart
│   ├── analytics/
│   │   ├── analytics_service.dart
│   │   └── metrics_service.dart
│   ├── ai/
│   │   ├── openai_service.dart
│   │   └── pinecone_service.dart
│   └── movie/
│       ├── movie_service.dart
│       └── scene_service.dart
│
└── widgets/
    ├── common/
    │   ├── custom_button.dart
    │   ├── loading_indicator.dart
    │   └── error_dialog.dart
    │
    ├── tutorial/
    │   ├── tutorial_overlay.dart
    │   └── feature_highlight.dart
    │
    ├── movie/
    │   ├── voice_input_button.dart
    │   └── scene_list.dart
    │
    └── profile/
        ├── profile_completion_card.dart
        └── interest_chips.dart
```

## Directory Purposes

### Config
- **constants.dart**: Application-wide constants and configuration values
- **routes.dart**: Route definitions and navigation configuration
- **theme/**: Theme-related configurations and constants

### Models
Each model type has its own directory for better organization:
- **user/**: User-related models and types
- **achievement/**: Achievement and reward models
- **video/**: Video-related models and metadata
- **movie/**: Movie creation and scene models
- **notification/**: Notification and alert models

### Screens
Feature-specific screens and their components:
- **auth/**: Authentication-related screens
- **onboarding/**: User onboarding flow
- **home/**: Main application screens
- **movie/**: Movie creation and editing
- **profile/**: User profile management

### Services
Each service is in its own directory for better organization and modularity:
- **auth/**: Authentication and user management
- **theme/**: Theme management and customization
- **achievements/**: User achievements and rewards
- **video/**: Video processing and management
- **social/**: Social interactions and notifications
- **analytics/**: User analytics and metrics
- **ai/**: AI integrations (OpenAI, Pinecone)
- **movie/**: Movie creation and scene management

### Widgets
Reusable UI components organized by feature:
- **common/**: Shared widgets used across the app
- **tutorial/**: Tutorial and onboarding widgets
- **movie/**: Movie-related UI components
- **profile/**: Profile-related widgets

## Best Practices

1. **File Organization**
   - Every feature has its own directory
   - Related files are grouped together
   - Clear separation between models, services, and UI
   - Consistent naming conventions

2. **Directory Structure**
   - Maximum depth of 3-4 levels
   - Feature-based organization
   - Clear separation of concerns
   - Modular and maintainable

3. **Naming Conventions**
   - snake_case for files and directories
   - Descriptive but concise names
   - Consistent suffixes (_screen, _service, etc.)
   - Clear purpose indication

4. **Code Organization**
   - One class per file
   - Feature-based grouping
   - Clear dependencies
   - Modular architecture

5. **Import Management**
   - Group imports by type
   - Use relative paths within features
   - Clear import organization
   - Minimal dependencies

## Development Guidelines

1. **Adding New Features**
   - Create feature directory in appropriate section
   - Follow existing patterns
   - Maintain modularity
   - Update documentation

2. **Modifying Existing Features**
   - Respect current organization
   - Maintain separation of concerns
   - Update related files
   - Keep documentation current

3. **Code Style**
   - Follow Flutter/Dart conventions
   - Consistent formatting
   - Clear documentation
   - Meaningful comments

4. **Testing**
   - Group tests with features
   - Maintain test coverage
   - Follow testing patterns
   - Document test cases

## Planned Structure (New Features)
```
lib/
├── screens/
│   ├── video/
│   │   ├── video_feed_screen.dart
│   │   ├── video_creation_screen.dart
│   │   ├── video_edit_screen.dart
│   │   └── components/
│   │       ├── video_player.dart
│   │       ├── video_controls.dart
│   │       ├── video_filters.dart
│   │       └── video_editor.dart
│   │
│   ├── social/
│   │   ├── followers_screen.dart
│   │   ├── following_screen.dart
│   │   ├── notifications_screen.dart
│   │   └── components/
│   │       ├── user_list_item.dart
│   │       └── notification_item.dart
│   │
│   └── analytics/
│       ├── analytics_dashboard.dart
│       └── components/
│           ├── engagement_chart.dart
│           └── metrics_card.dart
│
├── services/
│   ├── video/
│   │   ├── video_service.dart
│   │   ├── video_processing_service.dart
│   │   └── video_cache_service.dart
│   │
│   ├── social/
│   │   ├── social_service.dart
│   │   └── interaction_service.dart
│   │
│   └── analytics/
│       ├── analytics_service.dart
│       └── metrics_service.dart
│
├── models/
│   ├── video/
│   │   ├── video_model.dart
│   │   └── video_metadata.dart
│   │
│   ├── social/
│   │   ├── follower.dart
│   │   └── interaction.dart
│   │
│   └── analytics/
│       ├── engagement_metrics.dart
│       └── user_analytics.dart
│
└── widgets/
    ├── video/
    │   ├── video_player_controls.dart
    │   ├── video_progress_bar.dart
    │   └── video_thumbnail.dart
    │
    ├── social/
    │   ├── follow_button.dart
    │   ├── share_sheet.dart
    │   └── interaction_buttons.dart
    │
    └── analytics/
        ├── metrics_display.dart
        └── chart_widgets.dart
```

## Next Steps

1. **Create Base Structure**
   ```bash
   mkdir -p lib/{config,models,screens,services,widgets}/{auth,video,social,analytics}
   ```

2. **Implement Core Files**
   - Start with config and models
   - Add services as needed
   - Create placeholder widgets

3. **Feature Implementation**
   - Follow the planned structure
   - Implement one feature at a time
   - Keep code modular and testable

4. **Documentation**
   - Update this document as structure evolves
   - Document major architectural decisions
   - Keep README.md updated 