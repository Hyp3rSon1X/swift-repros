#include "words.h"

#include <string>
#include <vector>

int count_words(const char *text) {
  std::vector<std::string> words;
  std::string current;
  for (const char *p = text; *p; ++p) {
    if (*p == ' ') {
      if (!current.empty()) {
        words.push_back(current);
        current.clear();
      }
    } else {
      current.push_back(*p);
    }
  }
  if (!current.empty())
    words.push_back(current);
  return static_cast<int>(words.size());
}
