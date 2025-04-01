# Steam VDF Templates

These are template files for Steam's VDF (Valve Data Format) configuration used by SteamCMD to upload builds to Steam.

## Files

- `app_build.vdf.template`: Template for the main application build configuration
- `depot_build.vdf.template`: Template for the depot build configuration

## Usage

1. Copy these templates to your own location
2. Rename them to remove the `.template` extension
3. Replace the placeholder values with your actual Steam app and depot IDs
4. Configure the paths to point to your build output and content root

For more information on SteamCMD and VDF configuration, see the [Valve Developer Wiki](https://developer.valvesoftware.com/wiki/SteamCMD).

## Example Configuration

If you don't provide a `steam_vdf_path` in your settings, the deployer script will automatically generate basic VDF files for you based on your Steam app and depot IDs.

## Important Notes

- Make sure your Steam account has the necessary permissions to upload builds for your app
- You may need to enter your Steam Guard code when uploading for the first time
- For automated builds, consider setting up a dedicated Steam account with appropriate permissions
