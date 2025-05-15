#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void launch_language_checker(const char *lang, const char *file_path) {
    char command[512];

    if (strcmp(lang, "C") == 0) {
        snprintf(command, sizeof(command), "lex_c.exe \"%s\"", file_path);
    } else if (strcmp(lang, "C++") == 0) {
        snprintf(command, sizeof(command), "lex_cpp.exe \"%s\"", file_path);
    } else if (strcmp(lang, "Python") == 0) {
        snprintf(command, sizeof(command), "lex_python.exe \"%s\"", file_path);
    } else {
        printf("Unsupported or unknown language.\n");
        return;
    }

    printf("Running: %s\n", command);
    system(command);
}

int main() {
    // Step 1: Call detect_lang.py
    printf("Launching file selection dialog...\n");
    system("python detect_lang.py");

    // Step 2: Read language and path from temp.txt
    FILE *fp = fopen("temp.txt", "r");
    if (!fp) {
        perror("Failed to read temp.txt");
        return 1;
    }

    char lang[100], file_path[256];
    if (!fgets(lang, sizeof(lang), fp) || !fgets(file_path, sizeof(file_path), fp)) {
        printf("Failed to read language or file path.\n");
        fclose(fp);
        return 1;
    }

    // Clean up trailing newline
    lang[strcspn(lang, "\r\n")] = 0;
    file_path[strcspn(file_path, "\r\n")] = 0;

    printf("Selected file: %s\n", file_path);
    printf("Detected language: %s\n", lang);

    fclose(fp);

    // Step 3: Call the appropriate Lex-based analyzer
    launch_language_checker(lang, file_path);

    printf("\n✓ Analysis complete. Check 'output/result.txt' for results.\n");
    return 0;
}
