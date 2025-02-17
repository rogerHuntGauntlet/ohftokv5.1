Below is a proposed directory structure for refactoring your huge movie scenes screen into smaller, focused files. This new organization maintains the same design, layout, and functionality while improving readability and maintainability.

---

# Proposed Directory Structure

```
lib/
└── screens/
    └── movie/
        ├── movie_scenes_screen.dart       // Main screen file, sets up the scaffold and integrates all components.
        ├── dialogs/
        │   └── director_cut_dialog.dart   // Dialog for collecting director’s cut inputs.
        ├── modals/
        │   ├── scene_generation_modal.dart    // Modal shown during additional scene generation.
        │   └── video_generation_modal.dart    // Modal for displaying video generation progress.
        ├── widgets/
        │   ├── title_section.dart         // Widget to display/edit the movie title.
        │   ├── idea_section.dart          // Widget to display the movie idea.
        │   ├── scenes_list.dart           // Widget encapsulating the ListView and Add New Scene button.
        │   └── scene_card.dart            // Widget for rendering individual scenes.
        └── video_options_menu.dart        // Widget (typically a bottom sheet) providing video option actions.
```

---

# Description of the Files

- **movie_scenes_screen.dart**  
  This file remains the main entry point for the screen. It sets up the overall layout (app bar, body, bottom navigation) and manages high-level interactions by calling into the smaller widget and modal components.

- **dialogs/director_cut_dialog.dart**  
  Contains the dialog that allows the user to add a director’s cut version for a scene. All functionality regarding its display and data handling is encapsulated here.

- **modals/scene_generation_modal.dart & video_generation_modal.dart**  
  These modals present progress information while additional scenes are generated or while a video is being created. They encapsulate all progress UI details so that the main screen code stays clean.

- **widgets/title_section.dart**  
  A dedicated widget for displaying and editing the movie’s title. It houses the UI logic (and optionally, any related helper methods) for showing the title and triggering edit/create dialogs.

- **widgets/idea_section.dart**  
  Contains the UI for displaying the movie idea. This helps isolate the static content of your layout from the more dynamic scenes list.

- **widgets/scenes_list.dart**  
  This widget wraps the ListView.builder along with the “Add New Scene” button. It gathers and renders the list of scene cards while handling actions like scene deletion or notifying listeners when the scene list changes.

- **widgets/scene_card.dart**  
  Your existing scene card UI component now resides here. It’s responsible for rendering each individual scene’s details, status indicators, and action buttons inside the list.

- **video_options_menu.dart**  
  Implements the bottom sheet that allows users to choose video options (e.g., generate AI video, record video, upload from gallery). Separating this logic keeps the main screen’s code lean and focused.

---

# Benefits

- **Improved Readability:** Each file has a single, clear purpose. Developers can quickly navigate to the file of interest (for example, if only the title editing UI needs changes, look in the title_section.dart file).
- **Encapsulation:** Grouping related UI components and logic together makes unit testing and future changes easier.
- **Scalability:** As new features or enhancements are added to your movie scenes screen, they can be integrated into the appropriate module without cluttering the main screen file.

By breaking down the file into these components, you ensure that the application's core design, layout, and functionality remain unchanged while making the codebase cleaner and easier to manage.
