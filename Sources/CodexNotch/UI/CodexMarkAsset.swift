import AppKit
import Foundation

enum CodexMarkAsset {
    static let displayImage: NSImage? = {
        guard let data = Data(base64Encoded: embeddedDisplayPNGBase64, options: .ignoreUnknownCharacters),
              let image = NSImage(data: data) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }()

    static let templateImage: NSImage? = {
        guard let image = displayImage?.copy() as? NSImage else { return nil }
        image.isTemplate = true
        return image
    }()

    static let promptTemplateImage: NSImage? = {
        guard let data = Data(
            base64Encoded: embeddedTemplatePNGBase64,
            options: .ignoreUnknownCharacters
        ), let image = NSImage(data: data) else {
            return nil
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()

    // The original Codex artwork is inverted inside its enclosed prompt strokes.
    // The flower and exterior stay transparent; no other app is read at runtime.
    private static let embeddedTemplatePNGBase64 = """
    iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAABKUlEQVR42u3WPS9EQRjF8d9uxEpU
    RMIWIkIUGkKHTqL0CVQKSp9E4wvoRKUQDZVWofBeiELnJSRCZL2s1cwmt9hNFntzNzInmeRO8hT/
    OfOcZ26uUqloJeW1mCJQBIpAESgC/RegDTxjKm2gXAOP6xBO0YFjjGXt0BX2cINRLGbtEExiB2W8
    YgIvWfbQIbaQQxErWTsEA9hGJ74wjfssY38d1nvY96ThUNsPahcwjCdc4iJLoC4sB4cKWE2rhxoF
    WsJHSNY+jmrUzGIGpdD8SbVjFwfNACpiHCehb9Zr1AxiLQzPQgCqpqUc1hzm8fhXoDfcohubuKtR
    U8J5AiipzwD0EL6bEvs+9Na5qqr6MZJIYT6Mh+rBz+oc5tdzKP5+RKAIFIEiUATCN+yYRjX8a7on
    AAAAAElFTkSuQmCC
    """

    // Original flower silhouette with the original prompt retained in white.
    private static let embeddedDisplayPNGBase64 = """
    iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAFFElEQVR42rWYS2hcVRjHf+fMJNFI
    HeemIwbzMM2AJELFFFRKQRSyLgWlcaEVFWYjLtTixiyKCFIf3WSjMQpVdKEFFwE3gmhFjBFMUGOa
    R0HolDRkEsdq6DzuPS5yTvxyvDedkvHAZebee+45//P/3p/K5/OKf4cBlPiVzzQQ2mctwG3ATfZZ
    GfhbrJMCIq4/jP3dxpBOmCTBaLt4CBwAhoH7gX4gA1SBS8BPwFfAd3au9kBpu27k7bFjT+Ux5AOT
    i74APA3cnXAQgCIwCZwGLlqmEMxKBkMP1A6GjPdcCdEBfAA8Jd5HCUzeCRSAHuAbIG/3+BNYAn4E
    vrdg0kDdB6Ty+XySfN0HrwCv2v9agI0b0XXerwFTwOvAtzGgVJzIjJh4APjN3u+2UZy4jae0Wryv
    W/F/KPZSeJOMxwyW/lZx8kaHA5CylxZ7OHGdBR6ye6Wl5ksdcOg77QmeFErYjKGEQgNM+GLTnjUZ
    4CVruhPAHb6faNJIWRD9wBPy0Nqzpo+BN4C7Eqzv/xiPyr2cnA3wFvA4UEswaxr0vo0OpyL3AG1O
    jNpS96B1fE7BtCcm5Ym4WfoEcCtwi3vmUJ6MmeiYqZ05c4bZ2VmGhoYQ7r9Zoy49uQYC4JEYazKA
    6unpaRkeHqa9vZ1Tp041U2xund9tcE4BJhUEwb3AczEBTwGmXC6bgwcPqn379tHV1cXKyoqam5tT
    IoDuVWRtwBfAFSDlGEo6uQH02NjYlt9fW6NQKNDe3t4MfXLWvR/41KU3qSAIeoUDVDEfRaurq6q7
    u5v+/n6y2SxhGDI9Pe10aa8s1YHbgXVgSlsZ7ka/AhgfH2d9fZ21tTWOHTtGEAQIl9EMa3vG0b4I
    /JqQt2xTWywWuXz5MrVaDYBsNkuTnKcjYhDIu5v3dlk8AtTRo0fp7e3l6tWrzMzMsLy8HHkx0GWV
    SVe0C0OR9X99brExy1La+9AAOpPJMDIyQrFY5Nq1a0xMTMQptYzucZduILduS4vo+xjwtdX6Hcn+
    8ePHqdfrbG5uMjU1xfz8PEKhDaAOHz7MoUOHqFQqKLXTNlpaWjh//jyzs7PEuBcptpJjJGUTsUtA
    TrCkc7kcAwMDLCwskM1mOXfunG+2qquri9HRUdra2mhtbUUphTFbhw7DkCiKOHLkCIVCgXK5nFTV
    /AFccJlgCHSIKL99gmq1SqlUIpPJMDk5SalU8tmhUqmwtLS0DWhHXKjXiaKIjY0NwjDOZrYTti+B
    dZXP510ulLMWl/FFlsvl6OjocKKKLWE6Ozvp6+ujWq1uUas1UbRFdDqdZnFx0R3GZ8cBegD4weXU
    xrrwC0BvExxeo3l3zabIb9oAn9YiqFaAuQTzNw0EVTcn6TJinkvqW21ufdKpjvZ05rNd6jTdYGKf
    dCkxLw1sAC8CJ6SRaM9Dn7UVZzrBa+9VRAYoWUYGgbcF4EgmaLIWe1YgbiYoVzq/b3Vmxe5pZJml
    vaibtg2DE8Lz1oXrNyJEmBtkR9vGxDsx9Z/yyyAj0klXxD0M/GLvU0IPHFB1Ay2Xmv3uNWDZAyOr
    XJMKgkB5ZbILdBeBd4F5kZ64XtDP1l/d7NfmHpBQKPEnwPMx/SfZ3FBJ7RgT1wiw1YGxzalB4CPg
    vhjF9S3yNPCykEqUAAzHUFJKoESjIbI6ULPPrgDjVjn329DTIjYoAp/bxOusEHfkuYD/tGPULi02
    E0OrFKtksAfots6uZEX+l1DgMCHS72gl/gNDVsoWGC02JgAAAABJRU5ErkJggg==
    """
}
