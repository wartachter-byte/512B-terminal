#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>
#include <string.h>
#include <stdint.h>
#include <sys/stat.h>

#define MAX_NODES 4096
#define BASE_OFFSET 0x7E40
#define NODE_SIZE 3
#define START_SECTOR 3 // Sector 0: Boot, 1-2: Header

typedef struct {
    uint8_t character;
    uint16_t next_ptr;
} __attribute__((packed)) BinNode;

struct TrieNode {
    struct TrieNode *children[256];
    uint16_t sector_offset;
    int is_end;
};

BinNode flattened[MAX_NODES];
int current_free_idx = 0;

struct TrieNode *create_node() {
    return (struct TrieNode *)calloc(1, sizeof(struct TrieNode));
}

void insert(struct TrieNode *root, const char *word, uint16_t sector) {
    struct TrieNode *curr = root;
    for (int i = 0; word[i] != '\0'; i++) {
        unsigned char c = (unsigned char)word[i];
        if (!curr->children[c]) curr->children[c] = create_node();
        curr = curr->children[c];
    }
    curr->is_end = 1;
    curr->sector_offset = sector;
}

uint16_t serialize(struct TrieNode *node) {
    if (!node) return 0x0000;

    int child_count = 0;
    for (int i = 0; i < 256; i++) if (node->children[i]) child_count++;

    int my_level_start_idx = current_free_idx;
    current_free_idx += (child_count + 1);

    int write_ptr = my_level_start_idx;
    for (int i = 0; i < 256; i++) {
        if (node->children[i]) {
            flattened[write_ptr].character = (uint8_t)i;
            
            if (node->children[i]->is_end) {
                // Terminator: Store the SECTOR number in next_ptr
                flattened[write_ptr].next_ptr = node->children[i]->sector_offset;
            } else {
                // Branch: Store pointer to next layer
                uint16_t child_level_idx = serialize(node->children[i]);
                flattened[write_ptr].next_ptr = (uint16_t)(BASE_OFFSET + (child_level_idx * NODE_SIZE));
            }
            write_ptr++;
        }
    }

    // End of layer (\x00 terminator)
    flattened[write_ptr].character = 0x00;
    flattened[write_ptr].next_ptr = 0x0000;

    return (uint16_t)my_level_start_idx;
}

int main() {
    const char *src_dir = "./src/apps";
    const char *bin_out = "./bin/app_header";
    struct TrieNode *root = create_node();

    DIR *dir = opendir(src_dir);
    if (!dir) return perror("Apps directory missing"), 1;

    struct dirent *entry;
    uint16_t current_sector = START_SECTOR;

    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] == '.') continue;

        char bin_path[512];
        snprintf(bin_path, sizeof(bin_path), "./bin/%s.bin", entry->d_name);
        
        struct stat st;
        if (stat(bin_path, &st) == 0) {
            insert(root, entry->d_name, current_sector);
            // Calculate next sector (round up to 512 bytes)
            current_sector += (st.st_size + 511) / 512;
        }
    }
    closedir(dir);

    serialize(root);

    FILE *f = fopen(bin_out, "wb");
    if (f) {
        fwrite(flattened, NODE_SIZE, current_free_idx, f);
        fclose(f);
        printf("Trie Header saved. Apps start at sector %d.\n", START_SECTOR);
    }

    return 0;
}
