# 🚀 domiNixOS Installation Guide

This guide walks through installing **domiNixOS** from a live USB onto a fresh
machine using LUKS full-disk encryption and a customized Flake template.

## Step 1: Connect to the Internet

Boot into the NixOS Live USB. If you are using an Ethernet cable, you are
already connected. If you need Wi-Fi, use `nmtui`:

```bash
nmtui
```

_Select "Activate a connection", pick your network, enter the password, and quit._

## Step 2: Enter Root Shell & Prevent GitHub API Rate Limits

To avoid typing `sudo` for every command, switch to the root user now.

```bash
sudo -i
```

Because the installation pulls multiple Flakes from GitHub, you will likely hit
the 60-request/hour IP limit. Provide Nix with your GitHub Personal Access Token
(PAT) for the duration of this session:

```bash
export NIX_CONFIG="access-tokens = github.com=ghp_YOUR_TOKEN_HERE"
```

## Step 3: Disk Partitioning & Encryption

Set a variable for your disk to make copying and pasting easier. Check your
drive name using `lsblk`.

```bash
DISK=/dev/nvme0n1
```

**⚠️ IMPORTANT: Partition Naming Convention:**

- If you are using an **NVMe** drive (`/dev/nvme0n1`), the partitions will have
  a `p` suffix (e.g., `/dev/nvme0n1p1`).
- If you are using a **SATA/Standard** drive (`/dev/sda`), the partitions will
  **not** have a `p` (e.g., `/dev/sda1`).

Set your partition variables accordingly:

```bash
# For NVMe drives:
BOOT_PART="${DISK}p1"
ROOT_PART="${DISK}p2"

# For SATA drives, use these instead:
# BOOT_PART="${DISK}1"
# ROOT_PART="${DISK}2"
```

**1. Create the partitions (EFI Boot + Root):**

```bash
parted $DISK -- mklabel gpt
parted $DISK -- mkpart ESP fat32 1MB 4GB
parted $DISK -- set 1 esp on
parted $DISK -- mkpart primary 4GB 100%
```

**2. Encrypt the root partition:**

```bash
cryptsetup luksFormat $ROOT_PART
cryptsetup luksOpen $ROOT_PART cryptlvm
```

**3. Set up LVM (Logical Volumes for Swap and Root):**

```bash
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L 32G -n swap vg0   # use at least the size of your RAM for swap
lvcreate -l 100%FREE -n root vg0
```

**4. Format the partitions:**

```bash
mkfs.fat -F 32 -n boot $BOOT_PART
mkfs.ext4 -L root /dev/vg0/root
mkswap -L swap /dev/vg0/swap
```

## Step 4: Mount the File Systems

```bash
mount /dev/vg0/root /mnt
mkdir -p /mnt/boot
mount $BOOT_PART /mnt/boot
swapon /dev/vg0/swap
```

## Step 5: Download the domiNixOS Template

We will create your future user directory and clone your private template
repository into it.

```bash
USERNAME="username" # <-- Change this to your username!

# Create the target directory
mkdir -p /mnt/home/$USERNAME/.dominixos

# Clone your template repo into the folder
# Or if you have a personal version, clone that instead (make sure to update the URL):
git clone https://github.com/dominikoetiker/domiNixOS-template.git /mnt/home/$USERNAME/.dominixos
cd /mnt/home/$USERNAME/.dominixos
```

## Step 6: Generate Hardware Config & LUKS UUID

Now we populate the template files that depend on the physical hardware of this
specific machine, and apply a quick security patch to the boot partition.

**1. Generate the hardware configuration:**

```bash
nixos-generate-config --root /mnt --show-hardware-config > hardware-configuration.nix
```

**2. Fix the `/boot` world-accessible warning:**
_This automatically replaces the insecure default permissions with strict `0077`
permissions in the file we just generated._

```bash
sed -i 's/fmask=0022/fmask=0077/g' hardware-configuration.nix
sed -i 's/dmask=0022/dmask=0077/g' hardware-configuration.nix
```

**3. Generate the `crypt-uuid.nix` file dynamically:**
_This uses the `$ROOT_PART` variable you defined earlier to grab the correct
LUKS UUID._

```bash
echo "{ boot.initrd.luks.devices.\"cryptlvm\".device = \"/dev/disk/by-uuid/$(blkid -s UUID -o value $ROOT_PART)\"; }" > crypt-uuid.nix
```

## Step 7: Configure Your System

You now have your base template ready. Use the built-in `nano` editor to
customize it for this machine.

**1. Edit settings.nix:**

```bash
nano settings.nix
```

- Change `username`, `fullName`, and `email`.
- Set your `hostName`.
- Verify your `kernelModules.gpu` (e.g., `amdgpu`, `i915`, `nvme`).

**2. Edit flake.nix:**

```bash
nano flake.nix
```

- Check the `inputs` to ensure your NixVim branch follows the `nixos-xx.xx`
  release you want.
- Uncomment the specific modules you want for this machine.
- Pick your shell (`zsh` or `bash`).
- Add any machine-specific packages to the `environment.systemPackages` block.

## Step 8: The Golden Flake Rule

Nix Flakes strictly ignore any files that are not tracked by Git. Since we just
generated `hardware-configuration.nix` and `crypt-uuid.nix`, we must add them to
the Git staging area!

```bash
git add .
```

## Step 9: Install NixOS

Run the installation command, pointing it to the flake you just configured.
Replace `dominixos-btw` with whatever `hostName` you set in `settings.nix`!

```bash
nixos-install --flake .#dominixos-btw
```

## Step 10: Post-Installation & User Passwords

The `nixos-install` command only prompts you to set the `root` password. Before
we reboot, we need to set the password for your new personal user account so you
can actually log in!

**1. Set your user's password:**
_We use `nixos-enter` to temporarily "chroot" into your new system to run the
`passwd` command._

```bash
nixos-enter --root /mnt -c "passwd $USERNAME"
```

**2. Fix folder ownership:**
Once the installation finishes, you need to fix the ownership of your
`.dominixos` folder so it belongs to your new user, not the live environment's
root user.

```bash
chown -R 1000:100 /mnt/home/$USERNAME
```

_(User ID 1000 and Group ID 100 are the standard defaults for the first user
created in NixOS)._

**3. Unmount and reboot:**

```bash
umount -R /mnt
swapoff -a
reboot
```

🎉 **Welcome to domiNixOS!** Don't forget to log into 1Password and enable the
CLI integrations so your Git credentials work.

---

## 🛑 Troubleshooting: The DisplayLink EULA Error

If your installation halts with a red error about `displaylink-XXX.zip` and
complying with a EULA, you have hit a known issue with proprietary software in
NixOS. The build requires you to run a specific `nix-prefetch-url` command to
manually download the driver.

**The Problem:** You cannot easily copy/paste that long URL from a raw TTY screen.

**The Solution:**

1. Open your `flake.nix` file in `nano`.
2. Temporarily comment out the DisplayLink module by adding a `#` in front of it:
   `# dominix.nixosModules.displaylink`
3. Run `nixos-install --flake .#dominixos-btw` again. It will now succeed.
4. Continue to **Step 10** and reboot into your new graphical system.
5. Once inside your beautiful new GNOME desktop, open your Terminal (where you
   can easily copy and paste!).
6. Run the `nix-prefetch-url ...` command provided in the original error message.
7. Uncomment the module in `~/.dominixos/flake.nix` and run `nrs` (the
   alias for `sudo nixos-rebuild switch --flake ~/.dominixos`).

---

## 🛠️ Day 2: Owning domiNixOS

Once your system is up and running, here is how you manage, maintain, and truly
"own" your configuration.

### 1. Migrating Your Personal Config to GitHub

Right now, your `~/.dominixos` folder is just a local clone of the public
template repository. Since you have filled it with your personal `settings.nix`,
your specific `flake.nix`, and your machine's hardware configurations, you
should push it to your own GitHub repository to back it up!

_(Note: It is completely safe to make this repository public. LUKS UUIDs and
hardware configs are not secret data. Your actual passwords are safe in
1Password or hashed in the OS.)_

1. Go to GitHub and create a new, **completely empty** repository (e.g.,
   `my-nixos-config`). Do not add a README or .gitignore yet!
2. Open your terminal and navigate to your config folder:

   ```bash
   cd ~/.dominixos
   ```

3. Rename the link to the original template repository from `origin` to
   `upstream`. This allows us to fetch future updates from the template:

   ```bash
   git remote rename origin upstream
   ```

4. Link it to your new, empty repository (replace the URL with your actual
   repo URL):

   ```bash
   git remote add origin [https://github.com/YOUR_USERNAME/my-nixos-config.git](https://github.com/YOUR_USERNAME/my-nixos-config.git)
   ```

5. Push your personalized configuration up to GitHub:

   ```bash
   git push -u origin main
   ```

   _(If your local branch is named `master` instead of `main`, use
   `git push -u origin master`)_.

### 2. Pulling Updates from the Template

Whenever the public template gets updated with new features or modules, you
can easily merge those changes into your personalized configuration without
overwriting your `settings.nix`:

1. Fetch the latest changes from the template:

   ```bash
   cd ~/.dominixos
   git fetch upstream
   ```

2. Merge the changes into your local setup:

   ```bash
   git merge upstream/main
   ```

   _(Git will smartly merge new additions. If you modified the exact same
   lines as the template update, Git will prompt you to resolve the merge
   conflict manually.)_

3. Push the updated configuration to your private repository:
   ```bash
   git push origin main
   ```

### 3. Updating Your Packages

domiNixOS includes a custom, three-step workflow to safely update your system,
review changes before applying them, and track package versions using Git.

**Step 1: Check for Updates and Build**
Run the update check command. This will update your `flake.lock`, build the new
system in the background, and show you a detailed list of all package upgrades
and downgrades:

```bash
nuc
```

**Step 2: Apply the Updates**
Review the list of changes. If everything looks correct, apply the update.
Because the system was already compiled in the previous step, this will only
take a few seconds:

```bash
nrs
```

**Step 3: Commit the Changes**
To keep your configuration history clean and reproducible, automatically commit
the updated `flake.lock`. This script generates a detailed commit message
containing the exact list of changed packages:

```bash
nco
```

### 4. Upgrading to the Next NixOS Version

When a new version of NixOS drops (e.g., moving from `25.11` to `26.05`),
upgrading is incredibly simple.

1. Open `~/.dominixos/flake.nix`.
2. Update the version numbers in your inputs:

   ```nix
   inputs = {
     nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
     home-manager.url = "github:nix-community/home-manager/release-26.05";
     nixvim.url = "github:nix-community/nixvim/nixos-26.05";

     dominix.url = "github:dominikoetiker/domiNixOS";
   };
   ```

3. Run the update commands:

   ```bash
   cd ~/.dominixos
   nix flake update
   sudo nixos-rebuild switch --flake .
   ```

   Or just shourthand:

   ```bash
   nfu && nrs
   ```

4. **IMPORTANT:** Do _not_ change the `stateVersion` in your `settings.nix`!
   That must always remain the version you initially installed on the hardware,
   as it protects your local database formats from breaking.
