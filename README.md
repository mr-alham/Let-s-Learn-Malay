# Let's Learn Malay - Daily Language Learning Terminal Tool

**As part of my preparation for moving to Malaysia for higher studies, I needed to learn the Malay language. Being a frequent terminal user on Linux, I decided to integrate language learning into my daily workflow. I wrote this script and added it to my `.zshrc` file so that each new terminal session presents three new Malay words**

---

## Technical Overview

### **Language**:

- BASH

### **External Tolls**:

- jq - _For JSON parsing._
- curl - _To handle API requests._

### **Platform**

- Linux (Fedora)
- Visual Studio Code _(VS Code) for development._

### **Testing Tool**:

- Shellcheck - _Used to ensure proper syntax and detect potential issues in the script._

### **Files**:

- learn-malay.sh - _Main script, Where the logic happens._
- gemini.conf - _Holds the API key and configuration data for the gemini API._
- word-list.csv - _Pre-defined list of words Stored to fetch translations._
- data.state - _Tracks the user's progress, including the last accessed date and day._
- response.json - _Stores the last API response to enable offline access and to minimize API calls._

### Directory structure

```
/usr/local/
    |--- etc/
    |   |--- let-s-learn-malay/
    |       |--- word-list.csv
    |       |--- gemini.conf
    |
    |--- bin/
        |--- learn-malay  (learn-malay.sh)
```

---

## Example Output

![Example output of the script](https://i.ibb.co/f1V9CqX/Single-column-output-LET-S-LEARN-MALAY.png)

---

## How To Use

### Clone the repository:

```bash
git clone <repo>
```

### Move into the cloned directory

```bash
cd Lets-Learn-Malay
```

### Create the config directory in `/usr/local/etc/` and move the configs file into the directory

> Add the gemini API key into `gemini.conf` file

```bash
sudo mkdir let-s-learn-malay /usr/local/etc
sudo chown $USER:$USER -R /usr/local/etc/let-s-learn-malay
mv let-s-learn-malay/gemini.conf let-s-learn-malay/word-list.csv /usr/local/etc/let-s-learn-malay
mv learn-malay.sh learn-malay
mv learn-malay /usr/local/bin
```

> **Now use the script as a standard command by typing `learn-malay`**

> additionally add the command to `.zshrc` or `.bashrc` file

---

## Key Features

### Daily Word Display:

- The script displays three Malay words per day.
- For each word it provides:

  | \* Malay word                                                            | `bas`                                        |
  | ------------------------------------------------------------------------ | -------------------------------------------- |
  | \* Pronunciation guide for English speakers                              | `'bass'`                                     |
  | \* English Definition                                                    | `bus`                                        |
  | \* Example Malay sentences with English translations for better context. | `Bas itu penuh sesak. ─ The bus is crowded.` |

### Responsive Terminal Interface:

- The script adapts its output to the terminal window size. If the terminal has more space, it organizes data into single-row displays; otherwise, it dynamically splits the content into two or three rows, ensuring an optimal user experience regardless of terminal size.

#### Single column output

![Single column output example](https://i.ibb.co/f1V9CqX/Single-column-output-LET-S-LEARN-MALAY.png)

#### Double column output

![Double column output example](https://i.ibb.co/VtJd8Km/Double-column-output-LET-S-LEARN-MALAY.png)

### Three column output

![Three column output example](https://i.ibb.co/bPDLyLn/Three-column-output-LET-S-LEARN-MALAY.png)

### Offline Capability

- Instead of fetching data each time the script will save the data to use again.
- If for any reasons script couldn't fetch new data from API script will output previously saved data to avoid interruptions to avoid interruptions to the learning process

### Specifically configured Gemini-AI API

- If the `word-list.csv` does not exist the model will generate three words according to the learning state.

### User Tracking and State Management

- The learning state, including the last accessed day and the words shown, is tracked in a state file. This ensures that each user session picks up from where it left off, providing a seamless learning journey.

---
