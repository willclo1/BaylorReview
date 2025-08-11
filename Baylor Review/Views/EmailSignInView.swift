import SwiftUI

enum AuthMode {
  case signIn, signUp
}

struct EmailSignInView: View {
  @EnvironmentObject private var auth: AuthViewModel

  @State private var mode: AuthMode = .signIn
  @State private var email = ""
  @State private var password = ""
  @State private var fullName = ""
  @State private var year = ""
  @State private var major = ""

  var body: some View {
    ZStack {
      Color(hex: "#FFF5E1")
        .ignoresSafeArea()

      VStack(spacing: 32) {
        Image("logo2")
          .resizable()
          .scaledToFit()
          .frame(width: 120, height: 120)
          .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

        Text("Welcome to Baylor Review")
          .font(.title)
          .fontWeight(.bold)
          .foregroundColor(Color(hex: "004C26"))


        Picker("", selection: $mode) {
          Text("Sign In").tag(AuthMode.signIn)
          Text("Sign Up").tag(AuthMode.signUp)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, 24)

        // MARK: Input fields
        VStack(spacing: 16) {
          if mode == .signUp {
            TextField(
              "",
              text: $fullName,
              prompt: Text("Full Name").foregroundColor(Color(hex: "004C26").opacity(0.6))
            )
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            .foregroundColor(.black)
            .accentColor(Color(hex: "004C26"))

            TextField(
              "",
              text: $year,
              prompt: Text("Grad Year (e.g. 2026)").foregroundColor(Color(hex: "004C26").opacity(0.6))
            )
            .keyboardType(.numberPad)
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            .foregroundColor(.black)
            .accentColor(Color(hex: "004C26"))
              TextField(
                "",
                text: $major,
                prompt: Text("Major").foregroundColor(Color(hex: "004C26").opacity(0.6))
              )
              .padding()
              .background(Color.white)
              .cornerRadius(8)
              .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
              .foregroundColor(.black)
              .accentColor(Color(hex: "004C26"))
          }

          TextField(
            "",
            text: $email,
            prompt: Text("Email").foregroundColor(Color(hex: "004C26").opacity(0.6))
          )
          .keyboardType(.emailAddress)
          .autocapitalization(.none)
          .disableAutocorrection(true)
          .padding()
          .background(Color.white)
          .cornerRadius(8)
          .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
          .foregroundColor(.black)
          .accentColor(Color(hex: "004C26"))

          SecureField(
            "",
            text: $password,
            prompt: Text("Password").foregroundColor(Color(hex: "004C26").opacity(0.6))
          )
          .padding()
          .background(Color.white)
          .cornerRadius(8)
          .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
          .foregroundColor(.black)
          .accentColor(Color(hex: "004C26"))

          if let err = auth.errorMessage {
            Text(err)
              .foregroundColor(.red)
              .font(.caption)
              .multilineTextAlignment(.center)
              .padding(.top, 4)
          }
        }
        .padding(.horizontal, 24)

        // MARK: Action button
        Button(action: submit) {
          Text(mode == .signIn ? "Sign In" : "Create Account")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(mode == .signIn ? Color(hex: "004C26") : Color(hex: "F5B800"))
        .buttonBorderShape(.capsule)
        .padding(.horizontal, 24)

        Spacer()
      }
      .padding(.top, 40)
    }
  }

  private func submit() {
    auth.errorMessage = nil

    switch mode {
    case .signIn:
      auth.signIn(email: email, password: password)

    case .signUp:
      guard !fullName.isEmpty, !year.isEmpty else {
        auth.errorMessage = "Please fill in name and year."
        return
      }
      auth.signUp(
        email: email,
        password: password,
        fullName: fullName,
        year: year,
        major: major
      )
    }
  }
}

struct EmailSignInView_Previews: PreviewProvider {
  static var previews: some View {
    EmailSignInView()
      .environmentObject(AuthViewModel())
  }
}

