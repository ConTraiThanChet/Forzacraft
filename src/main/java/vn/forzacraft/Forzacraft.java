package vn.forzacraft;

import com.mojang.logging.LogUtils;
import net.minecraftforge.fml.common.Mod;
import org.slf4j.Logger;

@Mod(Forzacraft.MOD_ID)
public final class Forzacraft {
    public static final String MOD_ID = "forzacraft";
    public static final Logger LOGGER = LogUtils.getLogger();

    public Forzacraft() {
        LOGGER.info("Forzacraft loading");
    }
}
