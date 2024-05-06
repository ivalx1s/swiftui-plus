import Foundation
import UIKit

public protocol IDeepLinkHandler {
    func process(url: URL, in parentVC: UIViewController?) -> Bool
}
