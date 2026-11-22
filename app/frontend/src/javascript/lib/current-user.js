export default function normalizeCurrentUser (user) {
  if (Fablab.sessionTourMode && user?.profile_attributes) {
    user.profile_attributes.tours = Fablab.sessionTours;
  }
  return user;
}
