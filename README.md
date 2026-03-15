# RaffleEntryCollector

Kiosk-based raffle entry and lead collection app for the Final Frontier Security booth at CypherCon. Runs offline on a Raspberry Pi 4 with a 10.1" touchscreen.

## Testing on the Raspberry Pi

### 1. Clone the repo

```bash
git clone https://github.com/AndreRobitaille/RaffleEntryCollector.git
cd RaffleEntryCollector
```

### 2. Install Ruby 4.0

On Trixie, the easiest route is [mise](https://mise.jdx.dev/) (or rbenv):

```bash
# If mise isn't installed yet:
curl https://mise.jdx.dev/install.sh | sh
mise install ruby@4.0.0
mise use ruby@4.0.0
```

Alternatively, if Trixie's system Ruby is recent enough, use that.

### 3. Install dependencies and set up the database

```bash
bundle install
bin/rails db:create db:migrate
```

### 4. Boot the server

```bash
bin/rails server
```

### 5. Verify it works

```bash
# Quick test:
curl http://127.0.0.1:3000

# Or open Chromium in kiosk mode:
chromium-browser --kiosk http://127.0.0.1:3000
```
