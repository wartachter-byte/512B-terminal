#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>

#define MAX_NODES 2048
#define BASE_OFFSET 0x7E40  // The starting memory address of your header
#define NODE_SIZE 3         // Each node is exactly 3 bytes

/**
 * 3-BYTE NODE STRUCTURE
 * <char 1B> <pntr 2B>
 * pntr = BASE_OFFSET + (target_index * NODE_SIZE)
 */
typedef struct {
    uint8_t character;
    uint16_t next_ptr; 
} __attribute__((packed)) BinNode;

struct TrieNode {
    struct TrieNode *children[256];
    int is_end;
};

/* --- Trie Management --- */
struct TrieNode *create_node() {
    return calloc(1, sizeof(struct TrieNode));
}

void insert(struct TrieNode *root, const char *word) {
    struct TrieNode *curr = root;
    for (int i = 0; word[i] != '\0'; i++) {
        unsigned char c = (unsigned char)word[i];
        if (!curr->children[c]) curr->children[c] = create_node();
        curr = curr->children[c];
    }
    curr->is_end = 1;
}

/**
 * RECURSIVE SERIALIZATION
 * Calculates the memory-mapped pointer based on 0x7E40.
 */
BinNode flattened[MAX_NODES];
int current_free_idx = 0;

uint16_t serialize(struct TrieNode *node) {
    if (!node) return 0x0000;

    int child_count = 0;
    for (int i = 0; i < 256; i++) if (node->children[i]) child_count++;

    // Reserve space for this level's siblings + null terminator
    int my_level_start_idx = current_free_idx;
    current_free_idx += (child_count + 1);

    int write_ptr = my_level_start_idx;
    for (int i = 0; i < 256; i++) {
        if (node->children[i]) {
            flattened[write_ptr].character = (uint8_t)i;
            
            // Calculate the absolute memory pointer for the next level
            uint16_t child_level_idx = serialize(node->children[i]);
            
            if (child_level_idx == 0) {
                flattened[write_ptr].next_ptr = 0x0000; // End of word
            } else {
                // Pointer = Base + (Index * 3)
                flattened[write_ptr].next_ptr = (uint16_t)(BASE_OFFSET + (child_level_idx * NODE_SIZE));
            }
            write_ptr++;
        }
    }

    // Null terminator for the sibling list
    flattened[write_ptr].character = 0x00;
    flattened[write_ptr].next_ptr = 0x0000;

    return (uint16_t)my_level_start_idx;
}

int main() {
    const char *src_dir = "./src/apps";
    const char *bin_out = "./bin/app_header";
    struct TrieNode *root = create_node();

    DIR *dir = opendir(src_dir);
    struct dirent *entry;
    if (!dir) return perror("Source directory missing"), 1;

    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;
        insert(root, entry->d_name);
    }
    closedir(dir);

    // Build the flat structure starting from the root level
    serialize(root);

    int fd = open(bin_out, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd != -1) {
        write(fd, flattened, current_free_idx * NODE_SIZE);
        close(fd);
        printf("Binary header saved to %s\n", bin_out);
        printf("Base Address: 0x%04X, Total Nodes: %d\n", BASE_OFFSET, current_free_idx);
    }

    return 0;
}
