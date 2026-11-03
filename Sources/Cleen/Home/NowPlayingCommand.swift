/// Media commands, numbered as MediaRemote expects them.
enum NowPlayingCommand: Int {
    case play = 0
    case pause = 1
    /// What the buttons send; the model turns it into `play` or `pause` from what the
    /// player shows, so a press always does what its icon says.
    case playPause = 2
    case next = 4
    case previous = 5
}
