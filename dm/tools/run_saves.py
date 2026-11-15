"""Keep scratch builds and regression runs isolated from player cloud saves."""


class CloudSync(ValueError):
    """An option of the caller's own asked a run that is not the player's to sync its save with a cloud"""


def asked(pairs):
    """The DM_SAVE_SYNC value KEY=VALUE options set (the last one wins, as when they are merged in order), None when none sets it"""
    v = None
    for kv in pairs:
        k, _, val = kv.partition('=')
        if k in ('DM_SAVE_SYNC', 'NXE_CLOUD_FOLDER'): v = val
    return v


def cloud_off(env, ask=None):
    """env (a dict, changed in place and returned) with cloud saves off: DM_SAVE_SYNC=0, no DM_SAVE_SYNC_CHOICE. ask: the DM_SAVE_SYNC value the caller's own options set
    (asked(), a benchmark variant), None when they set none; one that turns sync on ('' and 0 do not) raises CloudSync"""
    if ask is not None and ask not in ('', '0'):
        raise CloudSync(f"DM_SAVE_SYNC={ask}: a run that is not the player's does not sync its save with a cloud")
    env['DM_SAVE_SYNC'] = '0'
    env.pop('DM_SAVE_SYNC_CHOICE', None)
    env.pop('NXE_CLOUD_FOLDER', None)
    return env
